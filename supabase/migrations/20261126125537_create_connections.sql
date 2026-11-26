-- Connections: friends are made by meeting in person.
--
-- One person shows a QR code holding a temporary token
-- (create_connection_token); the other scans it (scan_connection_token).
-- Showing one's QR code is the consent: a single scan makes the two friends.
-- Friends unlock messages and the like, and are the audience of the posts
-- "for friends".
--
-- A token works once, for 2 minutes (BusinessRules.connectionTokenLifetime):
-- a screenshot sent later is useless. When both people sent a recent
-- position, they must be at most 500 m apart
-- (BusinessRules.connectionMaxDistanceMeters): a QR code shown in a video
-- call does not connect anyone.
--
-- A friendship lasts until one of the two removes it, blocks the other or
-- deletes their account. The numbers mirror BusinessRules
-- (business_rules.dart); they are provisional until the release.

-- Tables ---------------------------------------------------------------------

create table public.connection_tokens (
  token text primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  expires_at timestamptz not null,
  used_at timestamptz
);

create index connection_tokens_user_id_idx on public.connection_tokens
  (user_id);
create index connection_tokens_expires_at_idx on public.connection_tokens
  (expires_at);

create table public.friendships (
  user_a uuid not null references auth.users (id) on delete cascade,
  user_b uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_a, user_b),
  -- A pair is stored once, whoever scanned.
  check (user_a < user_b)
);

create index friendships_user_b_idx on public.friendships (user_b);

alter table public.connection_tokens enable row level security;
alter table public.friendships enable row level security;

revoke all on public.connection_tokens from anon, authenticated;
revoke all on public.friendships from anon, authenticated;

-- Both are only used through the functions below.
create policy "Connection tokens are not accessible from the app"
  on public.connection_tokens for all
  to anon, authenticated
  using (false)
  with check (false);

create policy "Friendships are not accessible from the app"
  on public.friendships for all
  to anon, authenticated
  using (false)
  with check (false);

-- Friends --------------------------------------------------------------------

-- Whether a and b are friends. It replaces the placeholder of create_posts,
-- which always said no: the posts "for friends" and "for a list of friends"
-- now reach real friends.
create or replace function private.are_friends(a uuid, b uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.friendships
    where user_a = least(a, b) and user_b = greatest(a, b)
  );
$$;

-- Tokens ---------------------------------------------------------------------

-- A new token for the QR code of the signed-in user, valid 2 minutes and
-- once. Their previous tokens stop working: only the QR code on screen
-- connects.
create function public.create_connection_token()
returns table (token text, expires_at timestamptz)
language plpgsql
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  owner uuid := (select auth.uid());
  new_token text := replace(gen_random_uuid()::text, '-', '');
  new_expires_at timestamptz := now() + interval '2 minutes';
begin
  if not exists (
    select 1 from public.profiles where id = owner and is_complete
  ) then
    raise exception 'the profile must be complete to connect'
      using errcode = 'insufficient_privilege';
  end if;

  delete from public.connection_tokens where user_id = owner;
  insert into public.connection_tokens (token, user_id, expires_at)
  values (new_token, owner, new_expires_at);

  return query select new_token, new_expires_at;
end;
$$;

-- Connects the signed-in user with the owner of token, scanned from their QR
-- code, and returns who they are and whether they were already friends.
--
-- An unknown, expired or used token, or one of someone blocked either way,
-- fails the same way (no_data_found): the scanner never learns why. The
-- user's own token, or two people over 500 m apart, are refused
-- (check_violation).
create function public.scan_connection_token(token text)
returns table (friend_id uuid, already_friends boolean)
language plpgsql
security definer
set search_path = ''
as $$
#variable_conflict use_variable
declare
  scanner uuid := (select auth.uid());
  owner uuid;
  scanner_location public.user_locations;
  owner_location public.user_locations;
  inserted integer;
begin
  if not exists (
    select 1 from public.profiles where id = scanner and is_complete
  ) then
    raise exception 'the profile must be complete to connect'
      using errcode = 'insufficient_privilege';
  end if;

  select scanned.user_id into owner
  from public.connection_tokens as scanned
  where scanned.token = token
    and scanned.expires_at > now()
    and scanned.used_at is null
  for update;

  if owner = scanner then
    raise exception 'a user cannot connect with themselves'
      using errcode = 'check_violation';
  end if;

  if owner is null
    or private.is_blocked(scanner, owner)
    or not exists (
      select 1 from public.profiles where id = owner and is_complete
    )
  then
    raise exception 'this QR code is not valid'
      using errcode = 'no_data_found';
  end if;

  -- Checked only when both positions are recent: without one, for example
  -- for an invisible user, the QR code alone is trusted.
  select * into scanner_location
  from public.user_locations as location
  where location.user_id = scanner
    and location.recorded_at >= now() - interval '3 minutes';
  select * into owner_location
  from public.user_locations as location
  where location.user_id = owner
    and location.recorded_at >= now() - interval '3 minutes';
  if scanner_location.user_id is not null
    and owner_location.user_id is not null
    and not extensions.st_dwithin(
      scanner_location.geog, owner_location.geog, 500
    )
  then
    raise exception 'the two users are too far apart'
      using errcode = 'check_violation';
  end if;

  update public.connection_tokens as scanned
  set used_at = now()
  where scanned.token = token;

  insert into public.friendships (user_a, user_b)
  values (least(scanner, owner), greatest(scanner, owner))
  on conflict do nothing;
  get diagnostics inserted = row_count;

  return query select owner, inserted = 0;
end;
$$;

-- Reading and removing friends -----------------------------------------------

-- The signed-in user's friends, the most recent first. People they can no
-- longer see (with an incomplete profile, for example) are left out, through
-- get_public_profile.
create function public.my_friends()
returns table (
  user_id uuid,
  display_name text,
  age integer,
  avatar_path text,
  is_student_verified boolean,
  friends_since timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    person.id,
    person.display_name,
    person.age,
    person.avatar_path,
    person.is_student_verified,
    friendship.created_at
  from public.friendships as friendship
  cross join lateral public.get_public_profile(
    case
      when friendship.user_a = (select auth.uid()) then friendship.user_b
      else friendship.user_a
    end
  ) as person
  where (select auth.uid()) in (friendship.user_a, friendship.user_b)
  order by friendship.created_at desc;
$$;

-- Ends the friendship of the signed-in user with friend_id. The other is not
-- told; their messages and posts for friends close at once. Removing someone
-- who is not a friend does nothing.
create function public.remove_friend(friend_id uuid)
returns void
language sql
security definer
set search_path = ''
as $$
  delete from public.friendships
  where user_a = least((select auth.uid()), friend_id)
    and user_b = greatest((select auth.uid()), friend_id);
$$;

-- A block ends the friendship at once.
create function public.end_friendship_on_block()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  delete from public.friendships
  where user_a = least(new.blocker_id, new.blocked_id)
    and user_b = greatest(new.blocker_id, new.blocked_id);
  return new;
end;
$$;

create trigger on_block_end_friendship
  after insert on public.blocks
  for each row
  execute function public.end_friendship_on_block();

-- Access to the functions ----------------------------------------------------

revoke all on function public.create_connection_token() from public, anon;
revoke all on function public.scan_connection_token(text) from public, anon;
revoke all on function public.my_friends() from public, anon;
revoke all on function public.remove_friend(uuid) from public, anon;
revoke all on function public.end_friendship_on_block()
  from public, anon, authenticated;

grant execute on function public.create_connection_token() to authenticated;
grant execute on function public.scan_connection_token(text) to authenticated;
grant execute on function public.my_friends() to authenticated;
grant execute on function public.remove_friend(uuid) to authenticated;

-- Purge ----------------------------------------------------------------------

-- Deletes the tokens expired for an hour.
create function private.purge_old_connection_tokens()
returns void
language sql
set search_path = ''
as $$
  delete from public.connection_tokens
  where expires_at < now() - interval '1 hour';
$$;

revoke all on function private.purge_old_connection_tokens() from public;

select cron.schedule(
  'purge-old-connection-tokens',
  '0 * * * *',
  'select private.purge_old_connection_tokens()'
);
