begin;

create extension if not exists pgtap with schema extensions;

select plan(27);

-- Fixtures --------------------------------------------------------------------
-- Alice, Bob and Dan have complete profiles; Carol's is incomplete.

create function pg_temp.act_as(user_id uuid)
returns void
language plpgsql
as $$
begin
  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', user_id, 'role', 'authenticated')::text,
    true
  );
  set local role authenticated;
end;
$$;

insert into auth.users (id, email, email_confirmed_at) values
  ('00000000-0000-0000-0000-000000000001', 'alice@example.com', now()),
  ('00000000-0000-0000-0000-000000000002', 'bob@example.com', now()),
  ('00000000-0000-0000-0000-000000000003', 'carol@example.com', now()),
  ('00000000-0000-0000-0000-000000000004', 'dan@example.com', now());

insert into storage.objects (bucket_id, name, owner_id, metadata) values
  ('avatars', '00000000-0000-0000-0000-000000000001/a.jpg',
   '00000000-0000-0000-0000-000000000001', '{"mimetype": "image/jpeg"}'),
  ('avatars', '00000000-0000-0000-0000-000000000002/b.jpg',
   '00000000-0000-0000-0000-000000000002', '{"mimetype": "image/jpeg"}'),
  ('avatars', '00000000-0000-0000-0000-000000000002/old.jpg',
   '00000000-0000-0000-0000-000000000002', '{"mimetype": "image/jpeg"}'),
  ('avatars', '00000000-0000-0000-0000-000000000003/c.jpg',
   '00000000-0000-0000-0000-000000000003', '{"mimetype": "image/jpeg"}'),
  ('avatars', '00000000-0000-0000-0000-000000000004/d.jpg',
   '00000000-0000-0000-0000-000000000004', '{"mimetype": "image/jpeg"}');

update public.profiles
set display_name = 'Alice', gender = 'woman', avatar_path = id::text || '/a.jpg',
  birth_date = (current_date - interval '25 years')::date
where id = '00000000-0000-0000-0000-000000000001';

update public.profiles
set display_name = 'Bob', gender = 'man', avatar_path = id::text || '/b.jpg',
  birth_date = (current_date - interval '30 years' + interval '1 day')::date,
  bio = 'Hello'
where id = '00000000-0000-0000-0000-000000000002';

-- Carol has a photo but no birth date: incomplete.
update public.profiles
set display_name = 'Carol', gender = 'other', avatar_path = id::text || '/c.jpg'
where id = '00000000-0000-0000-0000-000000000003';

update public.profiles
set display_name = 'Dan', gender = 'man', avatar_path = id::text || '/d.jpg',
  birth_date = '1995-01-01'
where id = '00000000-0000-0000-0000-000000000004';

-- Public profile --------------------------------------------------------------

select pg_temp.act_as('00000000-0000-0000-0000-000000000001');

select is(
  (select count(*)::int
   from public.get_public_profile('00000000-0000-0000-0000-000000000002')),
  1,
  'a user can view a complete profile'
);
select is(
  (select age
   from public.get_public_profile('00000000-0000-0000-0000-000000000002')),
  29,
  'the age is computed by the server, the day before a birthday'
);
select is(
  (select bio
   from public.get_public_profile('00000000-0000-0000-0000-000000000002')),
  'Hello',
  'the public profile includes the bio'
);
select ok(
  position('birth_date' in pg_get_function_result(
    'public.get_public_profile(uuid)'::regprocedure
  )) = 0,
  'the public profile never returns the birth date'
);
select is(
  (select count(*)::int
   from public.get_public_profile('00000000-0000-0000-0000-000000000003')),
  0,
  'an incomplete profile is not visible'
);

-- Photos of other users -------------------------------------------------------

select is(
  (select count(*)::int from storage.objects
   where name = '00000000-0000-0000-0000-000000000002/b.jpg'),
  1,
  'a user can see the current photo of a visible profile'
);
select is(
  (select count(*)::int from storage.objects
   where name = '00000000-0000-0000-0000-000000000002/old.jpg'),
  0,
  'the other files of that folder stay private'
);
select is(
  (select count(*)::int from storage.objects
   where name = '00000000-0000-0000-0000-000000000003/c.jpg'),
  0,
  'the photo of an incomplete profile is not visible'
);

-- Blocks ----------------------------------------------------------------------

select throws_ok(
  $$insert into public.blocks (blocked_id)
    values ('00000000-0000-0000-0000-000000000001')$$,
  '23514',
  null,
  'a user cannot block themselves'
);
select lives_ok(
  $$insert into public.blocks (blocked_id)
    values ('00000000-0000-0000-0000-000000000002')$$,
  'a user can block someone'
);
select is(
  (select count(*)::int from public.blocks),
  1,
  'a user sees their own blocks'
);
select is(
  (select count(*)::int
   from public.get_public_profile('00000000-0000-0000-0000-000000000002')),
  0,
  'a blocked profile is no longer visible'
);
select is(
  (select count(*)::int from storage.objects
   where name = '00000000-0000-0000-0000-000000000002/b.jpg'),
  0,
  'the photo of a blocked profile is no longer visible'
);
select is(
  (select count(*)::int
   from public.get_public_profile('00000000-0000-0000-0000-000000000004')),
  1,
  'other profiles stay visible'
);

select pg_temp.act_as('00000000-0000-0000-0000-000000000002');

select is(
  (select count(*)::int
   from public.get_public_profile('00000000-0000-0000-0000-000000000001')),
  0,
  'the blocked user no longer sees the one who blocked them'
);
select is(
  (select count(*)::int from storage.objects
   where name = '00000000-0000-0000-0000-000000000001/a.jpg'),
  0,
  'nor their photo'
);
select is(
  (select count(*)::int from public.blocks),
  0,
  'the blocked user cannot see who blocked them'
);
select throws_ok(
  $$insert into public.blocks (blocker_id, blocked_id)
    values ('00000000-0000-0000-0000-000000000001',
            '00000000-0000-0000-0000-000000000004')$$,
  '42501',
  null,
  'a user cannot block on behalf of someone else'
);
select lives_ok(
  $$delete from public.blocks
    where blocker_id = '00000000-0000-0000-0000-000000000001'$$,
  'removing a block made by someone else runs without effect'
);

select pg_temp.act_as('00000000-0000-0000-0000-000000000001');

select is(
  (select count(*)::int from public.blocks),
  1,
  'the block made by the user is still there'
);

delete from public.blocks
where blocked_id = '00000000-0000-0000-0000-000000000002';

select is(
  (select count(*)::int
   from public.get_public_profile('00000000-0000-0000-0000-000000000002')),
  1,
  'after unblocking, the profile is visible again'
);

-- Incomplete viewer and visitors ----------------------------------------------

select pg_temp.act_as('00000000-0000-0000-0000-000000000003');

select is(
  (select count(*)::int
   from public.get_public_profile('00000000-0000-0000-0000-000000000001')),
  0,
  'a user with an incomplete profile cannot view others'
);
select is(
  (select count(*)::int from storage.objects
   where name = '00000000-0000-0000-0000-000000000001/a.jpg'),
  0,
  'nor their photos'
);

reset role;
set local role anon;

select throws_ok(
  $$select * from public.get_public_profile('00000000-0000-0000-0000-000000000001')$$,
  '42501',
  null,
  'visitors who are not signed in cannot view profiles'
);

-- Administrators --------------------------------------------------------------

reset role;
select pg_temp.act_as('00000000-0000-0000-0000-000000000001');

select throws_ok(
  $$select * from public.admins$$,
  '42501',
  null,
  'the list of administrators is not readable'
);
select is(private.is_admin(), false, 'a user is not an administrator');

reset role;
insert into public.admins (user_id)
values ('00000000-0000-0000-0000-000000000001');
select pg_temp.act_as('00000000-0000-0000-0000-000000000001');

select is(private.is_admin(), true, 'an added administrator is recognized');

select * from finish();

rollback;
