-- Blocks, administrators, and what users can see of each other's profiles.
--
-- Shared helpers live in the private schema, which the API does not expose:
-- the app cannot call them, for example to ask whether someone blocked it.
-- Policies can still use them.

create schema private;

grant usage on schema private to authenticated;

-- Tables ---------------------------------------------------------------------

create table public.blocks (
  blocker_id uuid not null default auth.uid()
    references auth.users (id) on delete cascade,
  blocked_id uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);

-- is_blocked looks up both directions.
create index blocks_blocked_id_idx on public.blocks (blocked_id);

-- Administrators are added by hand from the dashboard, never from the app.
create table public.admins (
  user_id uuid primary key references auth.users (id) on delete cascade,
  created_at timestamptz not null default now()
);

-- Access ---------------------------------------------------------------------

alter table public.blocks enable row level security;
alter table public.admins enable row level security;

revoke all on public.blocks from anon, authenticated;
revoke all on public.admins from anon, authenticated;

grant select, delete on public.blocks to authenticated;
grant insert (blocker_id, blocked_id) on public.blocks to authenticated;

-- A blocked user never learns who blocked them.
create policy "Users can read their own blocks"
  on public.blocks for select
  to authenticated
  using ((select auth.uid()) = blocker_id);

create policy "Users can block someone"
  on public.blocks for insert
  to authenticated
  with check ((select auth.uid()) = blocker_id);

create policy "Users can unblock someone"
  on public.blocks for delete
  to authenticated
  using ((select auth.uid()) = blocker_id);

-- Only read by the server, through private.is_admin().
create policy "Admins are not accessible from the app"
  on public.admins for all
  to anon, authenticated
  using (false)
  with check (false);

-- Shared helpers -------------------------------------------------------------

-- True when either user blocked the other. Every query that shows a user to
-- another one must exclude blocked pairs with it.
create function private.is_blocked(a uuid, b uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.blocks
    where (blocker_id = a and blocked_id = b)
      or (blocker_id = b and blocked_id = a)
  );
$$;

create function private.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.admins where user_id = (select auth.uid())
  );
$$;

-- Whether the signed-in user can see the profile of target: both profiles are
-- complete, and neither user blocked the other. Requiring a complete profile
-- keeps throwaway accounts from browsing others.
create function private.can_view_profile(target uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select (select auth.uid()) is not null
    and exists (
      select 1 from public.profiles
      where id = (select auth.uid()) and is_complete
    )
    and exists (
      select 1 from public.profiles
      where id = target and is_complete
    )
    and not private.is_blocked((select auth.uid()), target);
$$;

-- Whether the signed-in user can see the avatars file named object_name: only
-- the current photo of a profile they can view.
create function private.can_view_avatar(object_name text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.profiles
    where avatar_path = object_name
      and private.can_view_profile(id)
  );
$$;

revoke all on function private.is_blocked(uuid, uuid) from public;
revoke all on function private.is_admin() from public;
revoke all on function private.can_view_profile(uuid) from public;
revoke all on function private.can_view_avatar(text) from public;

grant execute on function private.is_blocked(uuid, uuid) to authenticated;
grant execute on function private.is_admin() to authenticated;
grant execute on function private.can_view_profile(uuid) to authenticated;
grant execute on function private.can_view_avatar(text) to authenticated;

-- Public profiles ------------------------------------------------------------

-- What a user sees of another profile. The birth date never leaves the
-- server: only the age is returned. Users still read their own full profile
-- from the profiles table.
create function public.get_public_profile(profile_id uuid)
returns table (
  id uuid,
  display_name text,
  age integer,
  gender text,
  bio text,
  occupation text,
  university text,
  is_student_verified boolean,
  avatar_path text
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    p.id,
    p.display_name,
    extract(year from age(current_date, p.birth_date))::integer,
    p.gender,
    p.bio,
    p.occupation,
    p.university,
    p.is_student_verified,
    p.avatar_path
  from public.profiles as p
  where p.id = profile_id
    and private.can_view_profile(p.id);
$$;

revoke all on function public.get_public_profile(uuid) from public, anon;
grant execute on function public.get_public_profile(uuid) to authenticated;

-- Photos of other users ------------------------------------------------------

create policy "Users can read the photo of profiles they can view"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'avatars'
    and private.can_view_avatar(name)
  );
