begin;

create extension if not exists pgtap with schema extensions;

select plan(36);

-- Fixtures --------------------------------------------------------------------
-- Alice is friends with Bob and Carol; Bob and Carol are not friends. Dave
-- has an incomplete profile.

create temp table people (name text primary key, id uuid not null);
grant select on people to authenticated;

create function pg_temp.user_id(person text)
returns uuid
language sql
as $$
  select id from people where name = person;
$$;

create function pg_temp.act_as(person text)
returns void
language plpgsql
as $$
begin
  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', pg_temp.user_id(person), 'role',
      'authenticated')::text,
    true
  );
  set local role authenticated;
end;
$$;

-- What happens when person likes friend: 'match', 'no match' or the error.
create function pg_temp.like(person text, friend text,
  message text default null)
returns text
language plpgsql
as $$
declare
  matched boolean;
begin
  perform pg_temp.act_as(person);
  matched := public.like_friend(pg_temp.user_id(friend), message);
  reset role;
  return case when matched then 'match' else 'no match' end;
exception when others then
  reset role;
  return 'error ' || sqlstate;
end;
$$;

-- What happens when person calls fn(friend): 'done' or the error.
create function pg_temp.call(person text, fn text, friend text)
returns text
language plpgsql
as $$
begin
  perform pg_temp.act_as(person);
  execute format('select public.%I(%L)', fn, pg_temp.user_id(friend));
  reset role;
  return 'done';
exception when others then
  reset role;
  return 'error ' || sqlstate;
end;
$$;

-- What person reads in one of their lists, as "name: detail" lines.
create function pg_temp.seen(person text, list text)
returns text
language plpgsql
as $$
declare
  result text;
begin
  perform pg_temp.act_as(person);
  execute case list
    when 'likes' then
      $q$select string_agg(display_name || ': ' || coalesce(message, '-'),
           ', ') from public.my_likes()$q$
    when 'matches' then
      $q$select string_agg(display_name || ': '
           || coalesce(their_message, '-') || ' / '
           || coalesce(my_message, '-'), ', ') from public.my_matches()$q$
    when 'notifications' then
      $q$select string_agg(kind || ' ' || display_name, ', '
           order by created_at, kind) from public.my_notifications()$q$
  end into result;
  reset role;
  return coalesce(result, 'nothing');
end;
$$;

insert into people (name, id)
select name, gen_random_uuid()
from unnest(array['alice', 'bob', 'carol', 'dave']) as name;

insert into auth.users (id, email, email_confirmed_at)
select id, name || '@example.com', now() from people;

insert into storage.objects (bucket_id, name, owner_id, metadata)
select 'avatars', id::text || '/a.jpg', id, '{"mimetype": "image/jpeg"}'
from people;

update public.profiles as profile
set display_name = initcap(people.name), gender = 'other',
  birth_date = '2000-01-01', avatar_path = profile.id::text || '/a.jpg'
from people
where people.id = profile.id and people.name <> 'dave';

insert into public.friendships (user_a, user_b)
select least(pg_temp.user_id('alice'), pg_temp.user_id(friend)),
  greatest(pg_temp.user_id('alice'), pg_temp.user_id(friend))
from unnest(array['bob', 'carol', 'dave']) as friend;

-- A secret like ---------------------------------------------------------------

select is(pg_temp.like('alice', 'bob', 'Coucou'), 'no match',
  'a like without a like back is no match');
select is(pg_temp.seen('alice', 'likes'), 'Bob: Coucou',
  'the user sees whom they liked, with their message');
select is(pg_temp.seen('bob', 'likes'), 'nothing',
  'the liked friend does not see the like in their likes');
select is(pg_temp.seen('bob', 'matches'), 'nothing',
  'nor in their matches');
select is(pg_temp.seen('bob', 'notifications'), 'nothing',
  'nor in their notifications');

select pg_temp.act_as('bob');
select throws_ok('select * from public.likes', '42501', null,
  'likes cannot be read directly');
select throws_ok('select count(*) from public.likes', '42501', null,
  'nor counted');
select throws_ok('select * from public.matches', '42501', null,
  'matches cannot be read directly');
select throws_ok('select * from public.notifications', '42501', null,
  'notifications cannot be read directly');
select throws_ok('select * from public.like_cooldowns', '42501', null,
  'cooldowns cannot be read directly');
reset role;

select is(pg_temp.like('alice', 'bob', 'Un café ?'), 'no match',
  'liking again before a match is allowed');
select is(pg_temp.seen('alice', 'likes'), 'Bob: Un café ?',
  'and replaces the message');
select is(pg_temp.like('alice', 'bob', '   '), 'no match',
  'a blank message is allowed');
select is(pg_temp.seen('alice', 'likes'), 'Bob: -',
  'and kept as no message');
select is(pg_temp.like('alice', 'bob', 'Un café ?'), 'no match',
  'the message can be given again');

-- Refusals --------------------------------------------------------------------

select is(pg_temp.like('bob', 'carol'), 'error 42501',
  'only a friend can be liked');
select is(pg_temp.like('alice', 'alice'), 'error 42501',
  'nobody can like themselves');
select is(pg_temp.like('dave', 'alice'), 'error 42501',
  'a user with an incomplete profile cannot like');
select is(pg_temp.like('alice', 'carol', repeat('a', 301)), 'error 23514',
  'a message over 300 characters is refused');

-- The match -------------------------------------------------------------------

select is(pg_temp.like('bob', 'alice', 'Avec plaisir'), 'match',
  'liking back makes a match at once');
select is(pg_temp.seen('alice', 'matches'), 'Bob: Avec plaisir / Un café ?',
  'the match reveals the friend''s message');
select is(pg_temp.seen('bob', 'matches'), 'Alice: Un café ? / Avec plaisir',
  'to both of them');
select is(pg_temp.seen('alice', 'notifications'), 'match Bob',
  'both are notified of the match');
select is(pg_temp.seen('bob', 'notifications'), 'match Alice',
  'both of them');
select is(pg_temp.seen('alice', 'likes'), 'nothing',
  'a matched like is no longer waiting');
select is(pg_temp.like('bob', 'alice'), 'match',
  'liking a match again changes nothing');
select is(
  (select count(*)::int from public.notifications),
  2,
  'and notifies nobody again'
);

-- Probing: like, then take back -----------------------------------------------

select is(pg_temp.call('bob', 'remove_like', 'alice'), 'error 23514',
  'a like cannot be removed after a match');

select is(pg_temp.call('bob', 'cancel_match', 'alice'), 'done',
  'a match can be cancelled');
select is(pg_temp.seen('alice', 'notifications'),
  'match Bob, match_cancelled Bob',
  'cancelling at once leaves the match notification, and tells the other');
select is(pg_temp.seen('alice', 'matches') || ' / '
    || pg_temp.seen('bob', 'likes'),
  'nothing / nothing',
  'the match and both likes are gone');
select is(pg_temp.like('alice', 'bob'), 'no match',
  'after a cancelled match, both can like again');

select is(pg_temp.like('carol', 'alice', 'Hello'), 'no match',
  'Carol likes Alice, who did not like her');
select pg_temp.call('carol', 'remove_like', 'alice');
select is(pg_temp.like('carol', 'alice'), 'error 54000',
  'a removed like cannot be given again to the same friend for 7 days');

update public.like_cooldowns set removed_at = now() - interval '8 days';

select is(pg_temp.like('carol', 'alice'), 'no match',
  'after 7 days it can');

-- Ending the friendship -------------------------------------------------------

select pg_temp.like('bob', 'alice');
select pg_temp.call('alice', 'remove_friend', 'bob');

select is(
  pg_temp.seen('alice', 'matches') || ' / ' || pg_temp.seen('carol', 'likes')
    || ' / ' || (select count(*)::text from public.likes
                 where pg_temp.user_id('bob') in (liker, liked)),
  'nothing / Alice: - / 0',
  'removing a friend deletes the likes and the match of the pair only'
);

select * from finish();

rollback;
