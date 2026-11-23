-- Posts, their audience, pins, and the bucket for their photos.
--
-- A post is a photo placed on the map for a limited time. Its place is the
-- author's current position or a place they picked nearby. Other users never
-- read that exact point: they get display_geog, the centre of a grid cell
-- (fuzzy, the default) or the point itself if the author chose "exact".
--
-- Posts are created and changed only through create_post and update_post,
-- which check every rule. The numbers below mirror BusinessRules
-- (business_rules.dart); they are provisional until the release.

-- Types ----------------------------------------------------------------------

create type public.post_precision as enum ('fuzzy', 'exact');
create type public.post_audience as enum ('everyone', 'friends', 'selected');

-- Location helpers -----------------------------------------------------------

-- The point at latitude, longitude, or null if either is null. Refuses
-- coordinates outside the globe.
create function private.point_from(latitude double precision,
  longitude double precision)
returns extensions.geography
language plpgsql
immutable
set search_path = ''
as $$
begin
  if latitude is null or longitude is null then
    return null;
  end if;
  if latitude not between -90 and 90 or longitude not between -180 and 180 then
    raise exception 'coordinates out of range'
      using errcode = 'check_violation';
  end if;
  return extensions.st_setsrid(
    extensions.st_makepoint(longitude, latitude), 4326
  )::extensions.geography;
end;
$$;

-- Centre of the grid cell holding point. Cells are about 300 m on each side
-- (BusinessRules.postFuzzyCellSizeMeters): 300 m of latitude, and as many
-- degrees of longitude as make 300 m at the latitude of the cell's centre.
--
-- The same point always gives the same centre. A random offset would not:
-- averaging the posts made from one place would reveal it.
create function private.fuzzy_point(point extensions.geography)
returns extensions.geography
language sql
immutable
set search_path = ''
as $$
  with cell_row as (
    select
      (floor(extensions.st_y(point::extensions.geometry) / size) + 0.5)
        * size as latitude,
      extensions.st_x(point::extensions.geometry) as longitude,
      size
    from (select 300 / 111320.0 as size) as cell
  ),
  cell as (
    select latitude, longitude, size / cos(radians(latitude)) as width
    from cell_row
  )
  select extensions.st_setsrid(
    extensions.st_makepoint(
      (floor(longitude / width) + 0.5) * width,
      latitude
    ),
    4326
  )::extensions.geography
  from cell;
$$;

revoke all on function private.point_from(double precision, double precision)
  from public;
revoke all on function private.fuzzy_point(extensions.geography) from public;

-- Friends --------------------------------------------------------------------

-- Whether a and b are friends. Friendships do not exist yet: they need real
-- meetups. Until then nobody is anyone's friend, so a post for friends is
-- seen by its author only. Replace this function when friendships ship.
create function private.are_friends(a uuid, b uuid)
returns boolean
language sql
stable
set search_path = ''
as $$
  select false;
$$;

revoke all on function private.are_friends(uuid, uuid) from public;
grant execute on function private.are_friends(uuid, uuid) to authenticated;

-- Tables ---------------------------------------------------------------------

create table public.posts (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null default auth.uid()
    references public.profiles (id) on delete cascade,
  -- One photo per post, in the author's folder of post-photos.
  image_path text not null unique,
  caption text,
  -- Never readable by users (column grants below).
  exact_geog extensions.geography(Point, 4326) not null,
  location_precision public.post_precision not null default 'fuzzy',
  -- What others see. Generated, so it always follows the precision.
  display_geog extensions.geography(Point, 4326) generated always as (
    case location_precision
      when 'exact' then exact_geog
      else private.fuzzy_point(exact_geog)
    end
  ) stored,
  audience public.post_audience not null default 'everyone',
  created_at timestamptz not null default now(),
  expires_at timestamptz not null,
  -- Like the carousel captions: absent, or not blank and at most 300
  -- characters (BusinessRules.postCaptionMaxLength).
  constraint posts_caption_length check (
    caption is null
    or (btrim(caption) <> '' and char_length(caption) <= 300)
  ),
  -- From 1 hour to 30 days after creation (BusinessRules.postMinLifetime and
  -- postMaxLifetime). Counted from the creation, so that changing the
  -- lifetime cannot keep a post forever.
  constraint posts_lifetime check (
    expires_at between created_at + interval '1 hour'
      and created_at + interval '30 days'
  ),
  constraint posts_image_path_own_folder check (
    image_path ~* ('^' || author_id::text || '/[^/]+\.(jpe?g|png|webp)$')
  )
);

create index posts_author_id_idx on public.posts (author_id);
create index posts_expires_at_idx on public.posts (expires_at);
create index posts_display_geog_idx on public.posts using gist (display_geog);

-- The friends who can see a post whose audience is 'selected'.
create table public.post_audience_members (
  post_id uuid not null references public.posts (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  primary key (post_id, user_id)
);

create index post_audience_members_user_id_idx
  on public.post_audience_members (user_id);

-- Posts a user keeps aside. Private: nobody else sees them, the author of the
-- post included, and nothing counts them.
create table public.pins (
  user_id uuid not null default auth.uid()
    references auth.users (id) on delete cascade,
  post_id uuid not null references public.posts (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, post_id)
);

create index pins_post_id_idx on public.pins (post_id);

-- Visibility -----------------------------------------------------------------

-- Whether the signed-in user can see the post post_id, of author and
-- audience, if it has not expired: the author always; others if they can
-- view the author's profile (both complete, no block either way) and belong
-- to the audience.
create function private.can_view_post(author uuid, post_id uuid,
  audience public.post_audience)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select (select auth.uid()) = author
    or (
      private.can_view_profile(author)
      and case audience
        when 'everyone' then true
        when 'friends' then private.are_friends(author, (select auth.uid()))
        when 'selected' then
          private.are_friends(author, (select auth.uid()))
          and exists (
            select 1
            from public.post_audience_members as member
            where member.post_id = can_view_post.post_id
              and member.user_id = (select auth.uid())
          )
        else false
      end
    );
$$;

revoke all on function private.can_view_post(uuid, uuid, public.post_audience)
  from public;
grant execute on function
  private.can_view_post(uuid, uuid, public.post_audience) to authenticated;

-- Access ---------------------------------------------------------------------

alter table public.posts enable row level security;
alter table public.post_audience_members enable row level security;
alter table public.pins enable row level security;

revoke all on public.posts from anon, authenticated;
revoke all on public.post_audience_members from anon, authenticated;
revoke all on public.pins from anon, authenticated;

-- Every column but exact_geog. No insert or update: create_post and
-- update_post do it.
grant select (
  id, author_id, image_path, caption, location_precision, display_geog,
  audience, created_at, expires_at
) on public.posts to authenticated;
grant delete on public.posts to authenticated;

grant select on public.post_audience_members to authenticated;

grant select, delete on public.pins to authenticated;
grant insert (post_id) on public.pins to authenticated;

-- An expired post disappears at once, for its author too, even before the
-- cleanup job deletes it.
create policy "Users can read the posts they can view"
  on public.posts for select
  to authenticated
  using (
    expires_at > now()
    and private.can_view_post(author_id, id, audience)
  );

create policy "Users can delete their own posts"
  on public.posts for delete
  to authenticated
  using ((select auth.uid()) = author_id);

-- Only the author sees who is in the audience of their post.
create policy "Authors can read the audience of their posts"
  on public.post_audience_members for select
  to authenticated
  using (
    exists (
      select 1 from public.posts as post
      where post.id = post_id
        and post.author_id = (select auth.uid())
    )
  );

create policy "Users can read their own pins"
  on public.pins for select
  to authenticated
  using ((select auth.uid()) = user_id);

-- The subquery runs with the policies of posts: only a visible post can be
-- pinned.
create policy "Users can pin the posts they can view"
  on public.pins for insert
  to authenticated
  with check (
    (select auth.uid()) = user_id
    and exists (select 1 from public.posts as post where post.id = post_id)
  );

create policy "Users can unpin"
  on public.pins for delete
  to authenticated
  using ((select auth.uid()) = user_id);

-- Public view ----------------------------------------------------------------

-- How the app reads posts: the displayed position as latitude and longitude.
-- With security_invoker, the policies of posts apply to the reader.
create view public.posts_public
with (security_invoker = true)
as
select
  post.id,
  post.author_id,
  post.image_path,
  post.caption,
  extensions.st_y(post.display_geog::extensions.geometry) as latitude,
  extensions.st_x(post.display_geog::extensions.geometry) as longitude,
  post.location_precision,
  post.audience,
  post.created_at,
  post.expires_at
from public.posts as post;

revoke all on public.posts_public from anon, authenticated;
grant select on public.posts_public to authenticated;

-- Creating and changing posts ------------------------------------------------

-- Refuses an audience list that does not match the audience: 'selected'
-- needs at least one friend of the author, the others no list at all.
create function private.check_post_audience(author uuid,
  audience public.post_audience, audience_ids uuid[])
returns void
language plpgsql
stable
set search_path = ''
as $$
begin
  if audience = 'selected' then
    if coalesce(cardinality(audience_ids), 0) = 0 then
      raise exception 'a selected audience needs at least one friend'
        using errcode = 'check_violation';
    end if;
    if exists (
      select 1 from unnest(audience_ids) as member(id)
      where member.id is null or not private.are_friends(author, member.id)
    ) then
      raise exception 'a selected audience can only list friends'
        using errcode = 'check_violation';
    end if;
  elsif coalesce(cardinality(audience_ids), 0) > 0 then
    raise exception 'audience_ids is only for a selected audience'
      using errcode = 'check_violation';
  end if;
end;
$$;

-- From 1 hour to 30 days (BusinessRules.postMinLifetime, postMaxLifetime).
create function private.check_post_lifetime(lifetime_minutes integer)
returns void
language plpgsql
immutable
set search_path = ''
as $$
begin
  if lifetime_minutes is null or lifetime_minutes not between 60 and 43200 then
    raise exception 'lifetime_minutes must be between 60 and 43200'
      using errcode = 'check_violation';
  end if;
end;
$$;

revoke all on function
  private.check_post_audience(uuid, public.post_audience, uuid[]) from public;
revoke all on function private.check_post_lifetime(integer) from public;

-- Creates a post of the signed-in user and returns its id.
--
-- device_latitude and device_longitude are the phone's position, sent by the
-- app: they are only used to check that a chosen place is at most 5 km away
-- (BusinessRules.postChosenLocationMaxDistanceMeters), and are not stored.
-- Without place_latitude and place_longitude, the post is at that position.
-- The photo must have been uploaded to the user's folder of post-photos.
create function public.create_post(
  image_path text,
  device_latitude double precision,
  device_longitude double precision,
  place_latitude double precision default null,
  place_longitude double precision default null,
  location_precision public.post_precision default 'fuzzy',
  lifetime_minutes integer default 1440,
  audience public.post_audience default 'everyone',
  audience_ids uuid[] default null,
  caption text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
#variable_conflict use_variable
declare
  author uuid := (select auth.uid());
  device extensions.geography;
  place extensions.geography;
  new_post_id uuid;
begin
  -- Locks the author's profile: two posts created at the same time cannot
  -- both pass the quota check.
  perform 1 from public.profiles as profile
  where profile.id = author and profile.is_complete
  for update;
  if not found then
    raise exception 'the profile must be complete to post'
      using errcode = 'insufficient_privilege';
  end if;

  -- At most 5 active posts (BusinessRules.activePostsMax).
  if (
    select count(*) from public.posts as post
    where post.author_id = author and post.expires_at > now()
  ) >= 5 then
    raise exception 'too many active posts'
      using errcode = 'program_limit_exceeded';
  end if;

  device := private.point_from(device_latitude, device_longitude);
  if device is null then
    raise exception 'the device position is required'
      using errcode = 'check_violation';
  end if;
  if (place_latitude is null) <> (place_longitude is null) then
    raise exception 'a place needs both a latitude and a longitude'
      using errcode = 'check_violation';
  end if;
  place := coalesce(private.point_from(place_latitude, place_longitude), device);
  if not extensions.st_dwithin(place, device, 5000) then
    raise exception 'the place is too far from the device position'
      using errcode = 'check_violation';
  end if;

  perform private.check_post_lifetime(lifetime_minutes);
  perform private.check_post_audience(author, audience, audience_ids);

  if not exists (
    select 1 from storage.objects as object
    where object.bucket_id = 'post-photos' and object.name = image_path
  ) then
    raise exception 'image_path must point to an uploaded photo'
      using errcode = 'check_violation';
  end if;

  insert into public.posts (
    author_id, image_path, caption, exact_geog, location_precision, audience,
    expires_at
  )
  values (
    author, image_path, caption, place, location_precision, audience,
    now() + make_interval(mins => lifetime_minutes)
  )
  returning id into new_post_id;

  if audience = 'selected' then
    insert into public.post_audience_members (post_id, user_id)
    select distinct new_post_id, member.id
    from unnest(audience_ids) as member(id);
  end if;

  return new_post_id;
end;
$$;

-- Changes the audience and/or the lifetime of a post of the signed-in user;
-- null leaves a setting as it is. The rest of a post cannot change: delete it
-- and post again.
--
-- The new lifetime is counted from the creation of the post, and must end in
-- the future: to remove a post now, delete it.
create function public.update_post(
  post_id uuid,
  audience public.post_audience default null,
  audience_ids uuid[] default null,
  lifetime_minutes integer default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
#variable_conflict use_variable
declare
  author uuid := (select auth.uid());
  post public.posts;
  new_audience public.post_audience;
begin
  select * into post
  from public.posts as existing
  where existing.id = post_id
    and existing.author_id = author
    and existing.expires_at > now()
  for update;
  if not found then
    raise exception 'post not found' using errcode = 'no_data_found';
  end if;

  if audience is not null or audience_ids is not null then
    new_audience := coalesce(audience, post.audience);
    perform private.check_post_audience(author, new_audience, audience_ids);

    update public.posts as existing
    set audience = new_audience
    where existing.id = post_id;

    delete from public.post_audience_members as member
    where member.post_id = post_id;

    if new_audience = 'selected' then
      insert into public.post_audience_members (post_id, user_id)
      select distinct post_id, member.id
      from unnest(audience_ids) as member(id);
    end if;
  end if;

  if lifetime_minutes is not null then
    perform private.check_post_lifetime(lifetime_minutes);
    if post.created_at + make_interval(mins => lifetime_minutes) <= now() then
      raise exception 'the new lifetime must end in the future'
        using errcode = 'check_violation';
    end if;

    update public.posts as existing
    set expires_at = post.created_at + make_interval(mins => lifetime_minutes)
    where existing.id = post_id;
  end if;
end;
$$;

revoke all on function public.create_post(
  text, double precision, double precision, double precision,
  double precision, public.post_precision, integer, public.post_audience,
  uuid[], text
) from public, anon;
grant execute on function public.create_post(
  text, double precision, double precision, double precision,
  double precision, public.post_precision, integer, public.post_audience,
  uuid[], text
) to authenticated;

revoke all on function public.update_post(
  uuid, public.post_audience, uuid[], integer
) from public, anon;
grant execute on function public.update_post(
  uuid, public.post_audience, uuid[], integer
) to authenticated;

-- Photos of the posts --------------------------------------------------------

-- Same limits as the other photos: 5 MB, JPEG, PNG or WebP. Keep them in sync
-- with BusinessRules.postPhotoMaxBytes and BusinessRules.postPhotoMimeTypes.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'post-photos',
  'post-photos',
  false,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp']
);

-- Whether the signed-in user can see the post-photos file named object_name:
-- only the photo of a post they can view.
create function private.can_view_post_photo(object_name text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.posts as post
    where post.image_path = object_name
      and post.expires_at > now()
      and private.can_view_post(post.author_id, post.id, post.audience)
  );
$$;

revoke all on function private.can_view_post_photo(text) from public;
grant execute on function private.can_view_post_photo(text) to authenticated;

create policy "Users can read their own post photos"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'post-photos'
    and (storage.foldername(name))[1] = (select auth.uid()::text)
  );

create policy "Users can read the photos of posts they can view"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'post-photos'
    and private.can_view_post_photo(name)
  );

create policy "Users can upload their own post photos"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'post-photos'
    and (storage.foldername(name))[1] = (select auth.uid()::text)
    and public.avatar_format_matches(name, metadata)
  );

-- The photo of a live post cannot be replaced, moved or deleted: delete the
-- post first. The subqueries run with the policies of posts, which show the
-- author their live posts.
create policy "Users can replace their unused post photos"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'post-photos'
    and (storage.foldername(name))[1] = (select auth.uid()::text)
    and not exists (
      select 1 from public.posts as post where post.image_path = name
    )
  )
  with check (
    bucket_id = 'post-photos'
    and (storage.foldername(name))[1] = (select auth.uid()::text)
    and public.avatar_format_matches(name, metadata)
  );

create policy "Users can delete their unused post photos"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'post-photos'
    and (storage.foldername(name))[1] = (select auth.uid()::text)
    and not exists (
      select 1 from public.posts as post where post.image_path = name
    )
  );
