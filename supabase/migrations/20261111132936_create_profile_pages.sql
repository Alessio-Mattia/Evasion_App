-- Free pages of the profile carousel, and the bucket for their photos.
--
-- The first carousel page is built from the profile itself (photo, name, age,
-- occupation). Users add up to 5 more pages, each from a template: text,
-- photo or interests. The numbers below mirror BusinessRules
-- (business_rules.dart); they are provisional until the release.

-- Interests ------------------------------------------------------------------

-- Codes of the predefined interests. Labels live in the app (app_fr.arb):
-- adding one needs a migration and an app update, and the app ignores codes
-- it does not know.
create function private.is_interest_list(interests jsonb)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select jsonb_typeof(interests) = 'array'
    and jsonb_array_length(interests) between 1 and 10
    and (
      select count(*) = count(distinct code)
        and bool_and(code in (
          'sport', 'music', 'movies', 'reading', 'travel', 'cooking',
          'gaming', 'art', 'nature', 'nightlife', 'technology',
          'photography', 'volunteering'
        ))
      from jsonb_array_elements_text(interests) as code
    );
$$;

revoke all on function private.is_interest_list(jsonb) from public;
grant execute on function private.is_interest_list(jsonb) to authenticated;

-- Pages ----------------------------------------------------------------------

create table public.profile_pages (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null default auth.uid()
    references public.profiles (id) on delete cascade,
  position smallint not null check (position between 1 and 5),
  type text not null check (type in ('text', 'photo', 'interests')),
  content jsonb not null default '{}',
  image_path text,
  created_at timestamptz not null default now(),
  -- Deferrable so that reorder_profile_pages can swap positions.
  constraint profile_pages_position_unique
    unique (profile_id, position) deferrable initially immediate,
  -- The content matches the template, with no other key.
  constraint profile_pages_content_matches_type check (
    (
      type = 'text'
      and image_path is null
      and content - 'text' = '{}'
      and jsonb_typeof(content -> 'text') = 'string'
      and btrim(content ->> 'text') <> ''
      and char_length(content ->> 'text') <= 300
    )
    or (
      type = 'photo'
      and image_path is not null
      and content - 'caption' = '{}'
      and (
        content -> 'caption' is null
        or (
          jsonb_typeof(content -> 'caption') = 'string'
          and char_length(content ->> 'caption') <= 100
        )
      )
    )
    or (
      type = 'interests'
      and image_path is null
      and content - 'interests' = '{}'
      and private.is_interest_list(content -> 'interests')
    )
  ),
  -- A photo of the user's own folder: <user id>/<file>.jpg, .png or .webp.
  constraint profile_pages_image_path_own_folder check (
    image_path ~* ('^' || profile_id::text || '/[^/]+\.(jpe?g|png|webp)$')
  )
);

alter table public.profile_pages enable row level security;

revoke all on public.profile_pages from anon, authenticated;

grant select, delete on public.profile_pages to authenticated;
grant insert (position, type, content, image_path)
  on public.profile_pages to authenticated;
grant update (position, type, content, image_path)
  on public.profile_pages to authenticated;

-- Same visibility as the profile: both complete, and no block either way.
create policy "Users can read their own pages and those of visible profiles"
  on public.profile_pages for select
  to authenticated
  using (
    (select auth.uid()) = profile_id
    or private.can_view_profile(profile_id)
  );

create policy "Users can add their own pages"
  on public.profile_pages for insert
  to authenticated
  with check ((select auth.uid()) = profile_id);

create policy "Users can change their own pages"
  on public.profile_pages for update
  to authenticated
  using ((select auth.uid()) = profile_id)
  with check ((select auth.uid()) = profile_id);

create policy "Users can delete their own pages"
  on public.profile_pages for delete
  to authenticated
  using ((select auth.uid()) = profile_id);

-- Reordering -----------------------------------------------------------------

-- Gives the user's pages the order of page_ids: the first one goes to
-- position 1. Swapping two pages one update at a time would briefly put two
-- pages at the same position, which the unique constraint refuses.
create function public.reorder_profile_pages(page_ids uuid[])
returns void
language plpgsql
set search_path = ''
as $$
begin
  if cardinality(page_ids) is distinct from (
    select count(*) from public.profile_pages
    where profile_id = (select auth.uid())
  ) or cardinality(page_ids) <> (
    select count(distinct page_id) from unnest(page_ids) as page_id
  ) or exists (
    select 1 from unnest(page_ids) as page_id
    where not exists (
      select 1 from public.profile_pages
      where id = page_id and profile_id = (select auth.uid())
    )
  ) then
    raise exception 'page_ids must list each page of the user exactly once'
      using errcode = 'invalid_parameter_value';
  end if;

  set constraints public.profile_pages_position_unique deferred;

  update public.profile_pages as page
  set position = ordered.position
  from unnest(page_ids) with ordinality as ordered(id, position)
  where page.id = ordered.id;
end;
$$;

revoke all on function public.reorder_profile_pages(uuid[]) from public, anon;
grant execute on function public.reorder_profile_pages(uuid[]) to authenticated;

-- Photos of the pages --------------------------------------------------------

-- Same limits as avatars: 5 MB, JPEG, PNG or WebP. Keep them in sync with
-- BusinessRules.profilePhotoMaxBytes and BusinessRules.profilePhotoMimeTypes.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'profile-photos',
  'profile-photos',
  false,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp']
);

-- The photo of a page must exist: a path alone would show an empty page.
create function public.check_page_photo_exists()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.image_path is not null and not exists (
    select 1
    from storage.objects
    where bucket_id = 'profile-photos'
      and name = new.image_path
  ) then
    raise exception 'image_path must point to an uploaded photo'
      using errcode = 'check_violation';
  end if;

  return new;
end;
$$;

create trigger check_profile_page_photo_exists
  before insert or update of image_path on public.profile_pages
  for each row
  execute function public.check_page_photo_exists();

revoke all on function public.check_page_photo_exists()
  from public, anon, authenticated;

-- Whether the signed-in user can see the profile-photos file named
-- object_name: only photos used by the pages of a profile they can view.
create function private.can_view_page_photo(object_name text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.profile_pages
    where image_path = object_name
      and private.can_view_profile(profile_id)
  );
$$;

revoke all on function private.can_view_page_photo(text) from public;
grant execute on function private.can_view_page_photo(text) to authenticated;

create policy "Users can read their own page photos"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'profile-photos'
    and (storage.foldername(name))[1] = (select auth.uid()::text)
  );

create policy "Users can read the page photos of profiles they can view"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'profile-photos'
    and private.can_view_page_photo(name)
  );

create policy "Users can upload their own page photos"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'profile-photos'
    and (storage.foldername(name))[1] = (select auth.uid()::text)
    and public.avatar_format_matches(name, metadata)
  );

-- A photo used by a page cannot be replaced, moved or deleted: upload a new
-- file, point the page to it, then delete the old one.
create policy "Users can replace their unused page photos"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'profile-photos'
    and (storage.foldername(name))[1] = (select auth.uid()::text)
    and not exists (
      select 1 from public.profile_pages where image_path = name
    )
  )
  with check (
    bucket_id = 'profile-photos'
    and (storage.foldername(name))[1] = (select auth.uid()::text)
    and public.avatar_format_matches(name, metadata)
  );

create policy "Users can delete their unused page photos"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'profile-photos'
    and (storage.foldername(name))[1] = (select auth.uid()::text)
    and not exists (
      select 1 from public.profile_pages where image_path = name
    )
  );
