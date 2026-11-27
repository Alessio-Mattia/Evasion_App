-- Likes and matches between friends, and the in-app notifications.
--
-- A like is secret: nobody can learn who liked them, except through a match,
-- which tells both at once. Liking is meant to be deliberate, not a way to
-- probe who liked you, so:
--   - the match is created in the same operation as the second like;
--   - both get a notification of the match, which nothing erases: cancelling
--     the match right away still leaves it, and adds a notification of the
--     cancellation for the other;
--   - a like cannot be removed once matched: only the match can be cancelled;
--   - a removed like cannot be given again to the same friend for 7 days
--     (BusinessRules.likeCooldownAfterRemoval).
-- A like may carry a message of at most 300 characters
-- (BusinessRules.likeMessageMaxLength), revealed only at the match.
--
-- Ending the friendship (removed friend or block) deletes the likes and the
-- match of the pair, silently, as the removal itself is.

-- Tables ---------------------------------------------------------------------

create table public.likes (
  liker uuid not null references auth.users (id) on delete cascade,
  liked uuid not null references auth.users (id) on delete cascade,
  message text check (
    message is null
    or (btrim(message) <> '' and char_length(message) <= 300)
  ),
  created_at timestamptz not null default now(),
  primary key (liker, liked),
  check (liker <> liked)
);

create index likes_liked_idx on public.likes (liked);

create table public.matches (
  user_a uuid not null references auth.users (id) on delete cascade,
  user_b uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_a, user_b),
  check (user_a < user_b)
);

create index matches_user_b_idx on public.matches (user_b);

-- When liker last removed a like to liked: they cannot like them again for
-- 7 days.
create table public.like_cooldowns (
  liker uuid not null references auth.users (id) on delete cascade,
  liked uuid not null references auth.users (id) on delete cascade,
  removed_at timestamptz not null default now(),
  primary key (liker, liked)
);

-- What happened to the user that they must know: for now a match, and a
-- cancelled match. Push notifications will be sent from it later.
create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  kind text not null check (kind in ('match', 'match_cancelled')),
  -- The other person concerned.
  other_user_id uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  read_at timestamptz
);

create index notifications_user_id_idx on public.notifications
  (user_id, created_at);

alter table public.likes enable row level security;
alter table public.matches enable row level security;
alter table public.like_cooldowns enable row level security;
alter table public.notifications enable row level security;

revoke all on public.likes from anon, authenticated;
revoke all on public.matches from anon, authenticated;
revoke all on public.like_cooldowns from anon, authenticated;
revoke all on public.notifications from anon, authenticated;

-- All four are used through the functions below only: nobody can read the
-- likes they received, not even by counting rows.
create policy "Likes are not accessible from the app"
  on public.likes for all to anon, authenticated
  using (false) with check (false);

create policy "Matches are not accessible from the app"
  on public.matches for all to anon, authenticated
  using (false) with check (false);

create policy "Like cooldowns are not accessible from the app"
  on public.like_cooldowns for all to anon, authenticated
  using (false) with check (false);

create policy "Notifications are not accessible from the app"
  on public.notifications for all to anon, authenticated
  using (false) with check (false);

-- Liking ---------------------------------------------------------------------

-- Likes the friend friend_id, with an optional message, and returns whether
-- it makes a match. Liking them again before a match replaces the message;
-- liking a friend already matched changes nothing.
--
-- Fails when friend_id is not a friend (insufficient_privilege), the message
-- is too long (check_violation), or the user removed their like to them less
-- than 7 days ago (program_limit_exceeded).
create function public.like_friend(friend_id uuid, message text default null)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
#variable_conflict use_variable
declare
  liker uuid := (select auth.uid());
  kept_message text := nullif(btrim(message), '');
begin
  if not exists (
    select 1 from public.profiles where id = liker and is_complete
  ) or not private.are_friends(liker, friend_id) then
    raise exception 'only a friend can be liked'
      using errcode = 'insufficient_privilege';
  end if;

  if char_length(kept_message) > 300 then
    raise exception 'the message is longer than 300 characters'
      using errcode = 'check_violation';
  end if;

  -- One pair at a time: two likes at once make a single match.
  perform pg_advisory_xact_lock(
    hashtextextended(
      least(liker, friend_id)::text || greatest(liker, friend_id)::text, 0
    )
  );

  if exists (
    select 1 from public.matches as match
    where match.user_a = least(liker, friend_id)
      and match.user_b = greatest(liker, friend_id)
  ) then
    return true;
  end if;

  if exists (
    select 1 from public.like_cooldowns as cooldown
    where cooldown.liker = liker
      and cooldown.liked = friend_id
      and cooldown.removed_at > now() - interval '7 days'
  ) then
    raise exception 'this like was removed less than 7 days ago'
      using errcode = 'program_limit_exceeded';
  end if;

  insert into public.likes (liker, liked, message)
  values (liker, friend_id, kept_message)
  on conflict on constraint likes_pkey
  do update set message = excluded.message;

  if not exists (
    select 1 from public.likes as other
    where other.liker = friend_id and other.liked = liker
  ) then
    return false;
  end if;

  -- The match, and its notification for both, in the same operation.
  insert into public.matches (user_a, user_b)
  values (least(liker, friend_id), greatest(liker, friend_id));
  insert into public.notifications (user_id, kind, other_user_id)
  values (liker, 'match', friend_id), (friend_id, 'match', liker);

  return true;
end;
$$;

-- Removes the user's like to friend_id, before any match: the friend never
-- learns of it, and it cannot be given again for 7 days. Once matched, a
-- like cannot be removed (check_violation): cancel the match instead.
-- Removing a like that does not exist does nothing.
create function public.remove_like(friend_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
#variable_conflict use_variable
declare
  liker uuid := (select auth.uid());
  removed integer;
begin
  perform pg_advisory_xact_lock(
    hashtextextended(
      least(liker, friend_id)::text || greatest(liker, friend_id)::text, 0
    )
  );

  if exists (
    select 1 from public.matches as match
    where match.user_a = least(liker, friend_id)
      and match.user_b = greatest(liker, friend_id)
  ) then
    raise exception 'a like cannot be removed after a match: cancel it'
      using errcode = 'check_violation';
  end if;

  delete from public.likes as like_row
  where like_row.liker = liker and like_row.liked = friend_id;
  get diagnostics removed = row_count;

  if removed > 0 then
    insert into public.like_cooldowns (liker, liked)
    values (liker, friend_id)
    on conflict on constraint like_cooldowns_pkey
    do update set removed_at = now();
  end if;
end;
$$;

-- Cancels the match with friend_id: the match and both likes disappear, and
-- the friend is told the match was cancelled. Both can like each other again
-- later. Cancelling a match that does not exist does nothing.
create function public.cancel_match(friend_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
#variable_conflict use_variable
declare
  user_id uuid := (select auth.uid());
  cancelled integer;
begin
  perform pg_advisory_xact_lock(
    hashtextextended(
      least(user_id, friend_id)::text || greatest(user_id, friend_id)::text, 0
    )
  );

  delete from public.matches as match
  where match.user_a = least(user_id, friend_id)
    and match.user_b = greatest(user_id, friend_id);
  get diagnostics cancelled = row_count;

  if cancelled > 0 then
    delete from public.likes as like_row
    where (like_row.liker = user_id and like_row.liked = friend_id)
      or (like_row.liker = friend_id and like_row.liked = user_id);
    insert into public.notifications (user_id, kind, other_user_id)
    values (friend_id, 'match_cancelled', user_id);
  end if;
end;
$$;

-- Reading --------------------------------------------------------------------

-- The friends the user liked and who did not like them back yet, with the
-- user's message, the most recent first. Never the likes the user received.
create function public.my_likes()
returns table (
  user_id uuid,
  display_name text,
  age integer,
  avatar_path text,
  is_student_verified boolean,
  message text,
  liked_at timestamptz
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
    like_row.message,
    like_row.created_at
  from public.likes as like_row
  cross join lateral public.get_public_profile(like_row.liked) as person
  where like_row.liker = (select auth.uid())
    and not exists (
      select 1 from public.matches as match
      where match.user_a = least(like_row.liker, like_row.liked)
        and match.user_b = greatest(like_row.liker, like_row.liked)
    )
  order by like_row.created_at desc;
$$;

-- The user's matches, the most recent first, with both messages: theirs for
-- the user, revealed by the match, and the user's own.
create function public.my_matches()
returns table (
  user_id uuid,
  display_name text,
  age integer,
  avatar_path text,
  is_student_verified boolean,
  their_message text,
  my_message text,
  matched_at timestamptz
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
    theirs.message,
    mine.message,
    match.created_at
  from public.matches as match
  cross join lateral (
    select case
      when match.user_a = (select auth.uid()) then match.user_b
      else match.user_a
    end as other_id
  ) as pair
  cross join lateral public.get_public_profile(pair.other_id) as person
  left join public.likes as theirs
    on theirs.liker = pair.other_id and theirs.liked = (select auth.uid())
  left join public.likes as mine
    on mine.liker = (select auth.uid()) and mine.liked = pair.other_id
  where (select auth.uid()) in (match.user_a, match.user_b)
  order by match.created_at desc;
$$;

-- The user's notifications, the most recent first: the 100 latest. People
-- the user can no longer see are left out.
create function public.my_notifications()
returns table (
  id uuid,
  kind text,
  user_id uuid,
  display_name text,
  avatar_path text,
  created_at timestamptz,
  read_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    notification.id,
    notification.kind,
    person.id,
    person.display_name,
    person.avatar_path,
    notification.created_at,
    notification.read_at
  from public.notifications as notification
  cross join lateral public.get_public_profile(
    notification.other_user_id
  ) as person
  where notification.user_id = (select auth.uid())
  order by notification.created_at desc
  limit 100;
$$;

-- Marks the user's notifications as read: those of ids, or all if null.
create function public.mark_notifications_read(ids uuid[] default null)
returns void
language sql
security definer
set search_path = ''
as $$
  update public.notifications
  set read_at = now()
  where user_id = (select auth.uid())
    and read_at is null
    and (ids is null or id = any (ids));
$$;

-- Ending a friendship --------------------------------------------------------

-- Likes and matches only exist between friends: a removed friend or a block
-- (which removes the friendship) deletes them, without any notification.
create function public.end_likes_with_friendship()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  delete from public.likes
  where (liker = old.user_a and liked = old.user_b)
    or (liker = old.user_b and liked = old.user_a);
  delete from public.matches
  where user_a = old.user_a and user_b = old.user_b;
  return old;
end;
$$;

create trigger on_friendship_end_likes
  after delete on public.friendships
  for each row
  execute function public.end_likes_with_friendship();

-- Access to the functions ----------------------------------------------------

revoke all on function public.like_friend(uuid, text) from public, anon;
revoke all on function public.remove_like(uuid) from public, anon;
revoke all on function public.cancel_match(uuid) from public, anon;
revoke all on function public.my_likes() from public, anon;
revoke all on function public.my_matches() from public, anon;
revoke all on function public.my_notifications() from public, anon;
revoke all on function public.mark_notifications_read(uuid[])
  from public, anon;
revoke all on function public.end_likes_with_friendship()
  from public, anon, authenticated;

grant execute on function public.like_friend(uuid, text) to authenticated;
grant execute on function public.remove_like(uuid) to authenticated;
grant execute on function public.cancel_match(uuid) to authenticated;
grant execute on function public.my_likes() to authenticated;
grant execute on function public.my_matches() to authenticated;
grant execute on function public.my_notifications() to authenticated;
grant execute on function public.mark_notifications_read(uuid[])
  to authenticated;

-- Purge ----------------------------------------------------------------------

-- Deletes the cooldowns that are over.
create function private.purge_old_like_cooldowns()
returns void
language sql
set search_path = ''
as $$
  delete from public.like_cooldowns
  where removed_at < now() - interval '7 days';
$$;

revoke all on function private.purge_old_like_cooldowns() from public;

select cron.schedule(
  'purge-old-like-cooldowns',
  '0 3 * * *',
  'select private.purge_old_like_cooldowns()'
);
