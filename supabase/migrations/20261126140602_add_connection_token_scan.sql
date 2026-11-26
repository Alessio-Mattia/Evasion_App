-- Who scanned my QR code: the person showing it sees the new connection at
-- once, and can undo it (remove_friend) if someone they did not want to
-- connect with scanned it, for example over their shoulder.

alter table public.connection_tokens
  add column used_by uuid references auth.users (id) on delete set null;

-- The same as in create_connections, keeping who used the token.
-- Connects the signed-in user with the owner of token, scanned from their QR
-- code, and returns who they are and whether they were already friends.
--
-- An unknown, expired or used token, or one of someone blocked either way,
-- fails the same way (no_data_found): the scanner never learns why. The
-- user's own token, or two people over 500 m apart, are refused
-- (check_violation).
create or replace function public.scan_connection_token(token text)
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
  set used_at = now(), used_by = scanner
  where scanned.token = token;

  insert into public.friendships (user_a, user_b)
  values (least(scanner, owner), greatest(scanner, owner))
  on conflict do nothing;
  get diagnostics inserted = row_count;

  return query select owner, inserted = 0;
end;
$$;

-- Who scanned token, if the signed-in user owns it and someone used it:
-- their public profile. Nothing while the token is unused, for a token of
-- someone else, or for someone the user can no longer see. The app asks
-- every few seconds while the QR code is on screen.
create function public.connection_token_scan(token text)
returns table (
  friend_id uuid,
  display_name text,
  age integer,
  avatar_path text,
  is_student_verified boolean
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
    person.is_student_verified
  from public.connection_tokens as scanned
  cross join lateral public.get_public_profile(scanned.used_by) as person
  where scanned.token = connection_token_scan.token
    and scanned.user_id = (select auth.uid())
    and scanned.used_by is not null;
$$;

revoke all on function public.connection_token_scan(text) from public, anon;
grant execute on function public.connection_token_scan(text) to authenticated;
