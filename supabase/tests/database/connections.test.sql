begin;

create extension if not exists pgtap with schema extensions;

select plan(30);

-- Fixtures --------------------------------------------------------------------
-- Alice, Bob, Dave and Eve have complete profiles; Carol's is incomplete.
-- Alice blocked Dave. Alice has a post for her friends.

create temp table people (name text primary key, id uuid not null);
grant select on people to authenticated;

-- Tokens and results kept between steps, readable while acting as a user.
create temp table kept (name text primary key, value text);
grant select, insert, update on kept to authenticated;

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

-- The current QR token of person, created while acting as them.
create function pg_temp.new_token(person text)
returns text
language plpgsql
as $$
declare
  created text;
begin
  perform pg_temp.act_as(person);
  select token into created from public.create_connection_token();
  reset role;
  return created;
end;
$$;

-- What happens when scanner scans token: the result as text, or the error.
create function pg_temp.scan(scanner text, token text)
returns text
language plpgsql
as $$
declare
  result text;
begin
  perform pg_temp.act_as(scanner);
  select (select initcap(name) from people where id = friend_id) || ', '
      || case when already_friends then 'already friends' else 'connected'
         end
    into result
  from public.scan_connection_token(token);
  reset role;
  return result;
exception when others then
  reset role;
  return 'error ' || sqlstate;
end;
$$;

-- Whether a and b are friends, read as the database owner.
create function pg_temp.friends(a text, b text)
returns boolean
language sql
as $$
  select private.are_friends(pg_temp.user_id(a), pg_temp.user_id(b));
$$;

-- Puts the latest position of person north metres from the EPFL, just now.
create function pg_temp.place(person text, north double precision)
returns void
language sql
as $$
  insert into public.user_locations (user_id, geog, accuracy_m)
  values (pg_temp.user_id(person),
          private.point_from(46.5191 + north / 111320.0, 6.5668), 10)
  on conflict (user_id) do update set geog = excluded.geog,
    recorded_at = now();
$$;

insert into people (name, id)
select name, gen_random_uuid()
from unnest(array['alice', 'bob', 'carol', 'dave', 'eve']) as name;

insert into auth.users (id, email, email_confirmed_at)
select id, name || '@example.com', now() from people;

insert into storage.objects (bucket_id, name, owner_id, metadata)
select 'avatars', id::text || '/a.jpg', id, '{"mimetype": "image/jpeg"}'
from people;

update public.profiles as profile
set display_name = initcap(people.name), gender = 'other',
  birth_date = '2000-01-01', avatar_path = profile.id::text || '/a.jpg'
from people
where people.id = profile.id and people.name <> 'carol';

insert into public.blocks (blocker_id, blocked_id)
values (pg_temp.user_id('alice'), pg_temp.user_id('dave'));

insert into public.posts (author_id, image_path, exact_geog, audience,
  created_at, expires_at)
values (pg_temp.user_id('alice'), pg_temp.user_id('alice')::text || '/f.jpg',
  'POINT(6.5668 46.5191)', 'friends', now(), now() + interval '1 day');

-- Tokens ----------------------------------------------------------------------

insert into kept values ('first alice token', pg_temp.new_token('alice'));
insert into kept values ('alice token', pg_temp.new_token('alice'));

select is(
  (select length(value) from kept where name = 'alice token'),
  32,
  'a token is a random string of 32 characters'
);
select is(
  (select expires_at - now() from public.connection_tokens
   where token = (select value from kept where name = 'alice token')),
  interval '2 minutes',
  'a token lasts 2 minutes'
);
select is(
  pg_temp.scan('bob', (select value from kept where name = 'first alice token')),
  'error P0002',
  'a new token replaces the previous one'
);

-- Connecting ------------------------------------------------------------------

select is(
  pg_temp.scan('bob', (select value from kept where name = 'alice token')),
  'Alice, connected',
  'scanning a QR code once makes two people friends'
);
select ok(pg_temp.friends('alice', 'bob'), 'the friendship goes both ways');
select is(
  (select count(*)::int from public.friendships),
  1,
  'a pair is stored once'
);
select is(
  pg_temp.scan('eve', (select value from kept where name = 'alice token')),
  'error P0002',
  'a token works only once'
);
select is(
  pg_temp.scan('bob', pg_temp.new_token('alice')),
  'Alice, already friends',
  'scanning a friend again changes nothing'
);
select is(
  (select count(*)::int from public.friendships),
  1,
  'still one friendship'
);

-- Refusals --------------------------------------------------------------------

select is(
  pg_temp.scan('alice', pg_temp.new_token('alice')),
  'error 23514',
  'a user cannot scan their own QR code'
);

insert into kept values ('eve token', pg_temp.new_token('eve'));
update public.connection_tokens set expires_at = now() - interval '1 second'
where token = (select value from kept where name = 'eve token');

select is(
  pg_temp.scan('bob', (select value from kept where name = 'eve token')),
  'error P0002',
  'an expired token is refused'
);
select is(
  pg_temp.scan('bob', 'not-a-token'),
  'error P0002',
  'an unknown token is refused'
);
select is(
  pg_temp.scan('dave', pg_temp.new_token('alice')),
  'error P0002',
  'a blocked user cannot connect, and does not learn why'
);
select is(
  pg_temp.scan('alice', pg_temp.new_token('dave')),
  'error P0002',
  'nor can the user who blocked'
);
select is(
  pg_temp.scan('carol', pg_temp.new_token('eve')),
  'error 42501',
  'a user with an incomplete profile cannot scan'
);

select pg_temp.act_as('carol');
select throws_ok(
  'select * from public.create_connection_token()',
  '42501', null, 'a user with an incomplete profile cannot show a QR code'
);
reset role;

-- Proximity -------------------------------------------------------------------

select pg_temp.place('alice', 0);
select pg_temp.place('eve', 1000);

select is(
  pg_temp.scan('eve', pg_temp.new_token('alice')),
  'error 23514',
  'two people with recent positions 1 km apart cannot connect'
);

select pg_temp.place('eve', 100);

select is(
  pg_temp.scan('eve', pg_temp.new_token('alice')),
  'Alice, connected',
  'two people 100 m apart can'
);

-- Reading ---------------------------------------------------------------------

-- The whole test runs at the same instant: date Bob's friendship back so
-- that the order is clear.
update public.friendships set created_at = now() - interval '1 day'
where pg_temp.user_id('bob') in (user_a, user_b);

select pg_temp.act_as('alice');

select results_eq(
  'select display_name from public.my_friends()',
  $$values ('Eve'), ('Bob')$$,
  'a user reads their friends, the most recent first'
);

select pg_temp.act_as('bob');

select results_eq(
  'select display_name from public.my_friends()',
  $$values ('Alice')$$,
  'the other one sees the friendship too'
);
select is(
  (select count(*)::int from public.posts_public
   where author_id = pg_temp.user_id('alice')),
  1,
  'a friend sees a post for friends'
);
select throws_ok(
  'select * from public.friendships',
  '42501', null, 'friendships cannot be read directly'
);
select throws_ok(
  'select * from public.connection_tokens',
  '42501', null, 'tokens cannot be read directly'
);

-- Removing --------------------------------------------------------------------

select public.remove_friend(pg_temp.user_id('alice'));

select is_empty(
  'select * from public.my_friends()',
  'a user can remove a friend'
);
select is(
  (select count(*)::int from public.posts_public
   where author_id = pg_temp.user_id('alice')),
  0,
  'a removed friend no longer sees the posts for friends'
);

reset role;

select ok(not pg_temp.friends('alice', 'bob'), 'for both of them');

insert into public.blocks (blocker_id, blocked_id)
values (pg_temp.user_id('eve'), pg_temp.user_id('alice'));

select ok(
  not pg_temp.friends('alice', 'eve'),
  'a block ends the friendship at once'
);

-- Purge and access ------------------------------------------------------------

update public.connection_tokens
set expires_at = now() - interval '2 hours'
where token = (select value from kept where name = 'eve token');
select private.purge_old_connection_tokens();

select is(
  (select count(*)::int from public.connection_tokens
   where token = (select value from kept where name = 'eve token')),
  0,
  'the purge deletes the tokens expired for an hour'
);
select is(
  (select schedule from cron.job
   where jobname = 'purge-old-connection-tokens'),
  '0 * * * *',
  'the purge runs every hour'
);
select ok(
  not has_function_privilege(
    'anon', 'public.scan_connection_token(text)', 'execute'
  ),
  'signed-out users cannot connect'
);

select * from finish();

rollback;
