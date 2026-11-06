begin;

create extension if not exists pgtap with schema extensions;

select plan(39);

-- Fixtures --------------------------------------------------------------------

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
  ('00000000-0000-0000-0000-000000000003', 'carol@epfl.ch', null),
  ('00000000-0000-0000-0000-000000000004', 'dan@epfl.ch', now());

-- Sign-up ---------------------------------------------------------------------

select is(
  (select count(*)::int from public.profiles),
  4,
  'sign-up creates a profile'
);
select is(
  (select count(*)::int from public.user_settings),
  4,
  'sign-up creates settings'
);
select is(
  (select location_mode::text from public.user_settings
   where user_id = '00000000-0000-0000-0000-000000000001'),
  'invisible',
  'a new user is invisible'
);
select is(
  (select detection_radius_m from public.user_settings
   where user_id = '00000000-0000-0000-0000-000000000001'),
  100,
  'the detection radius defaults to 100 m'
);
select is(
  (select is_complete from public.profiles
   where id = '00000000-0000-0000-0000-000000000001'),
  false,
  'a new profile is not complete'
);

-- Student badge ---------------------------------------------------------------

select is(
  (select is_student_verified from public.profiles
   where id = '00000000-0000-0000-0000-000000000003'),
  false,
  'no badge before the email is confirmed'
);

update auth.users set email_confirmed_at = now()
where id = '00000000-0000-0000-0000-000000000003';

select is(
  (select is_student_verified from public.profiles
   where id = '00000000-0000-0000-0000-000000000003'),
  true,
  'badge once a university email is confirmed'
);
select is(
  (select is_student_verified from public.profiles
   where id = '00000000-0000-0000-0000-000000000004'),
  true,
  'badge when the email is already confirmed at sign-up'
);
select is(
  (select is_student_verified from public.profiles
   where id = '00000000-0000-0000-0000-000000000001'),
  false,
  'no badge for another domain'
);

update auth.users set email = 'carol@example.com'
where id = '00000000-0000-0000-0000-000000000003';

select is(
  (select is_student_verified from public.profiles
   where id = '00000000-0000-0000-0000-000000000003'),
  false,
  'badge removed when the email leaves the university'
);

update auth.users set email = 'alice@unil.ch'
where id = '00000000-0000-0000-0000-000000000001';

select is(
  (select is_student_verified from public.profiles
   where id = '00000000-0000-0000-0000-000000000001'),
  true,
  'badge granted when the email becomes a university one'
);

update auth.users set email = 'alice@example.com'
where id = '00000000-0000-0000-0000-000000000001';

-- Domain matching -------------------------------------------------------------

select ok(public.is_university_email('a@epfl.ch'), 'exact domain');
select ok(public.is_university_email('a@students.unil.ch'), 'subdomain');
select ok(public.is_university_email('A@EPFL.CH'), 'case insensitive');
select ok(not public.is_university_email('a@fakeunil.ch'), 'lookalike domain');
select ok(not public.is_university_email('a@unil.ch.evil.com'), 'domain as a prefix');
select ok(not public.is_university_email('a@example.com'), 'other domain');

-- Minimum age -----------------------------------------------------------------

select throws_ok(
  $$update public.profiles
    set birth_date = (current_date - interval '18 years' + interval '1 day')::date
    where id = '00000000-0000-0000-0000-000000000002'$$,
  '23514',
  'the user is under the minimum age',
  'one day before turning 18 is refused'
);
select lives_ok(
  $$update public.profiles
    set birth_date = (current_date - interval '18 years')::date
    where id = '00000000-0000-0000-0000-000000000002'$$,
  'exactly 18 is accepted'
);
select throws_ok(
  $$update public.profiles set birth_date = null
    where id = '00000000-0000-0000-0000-000000000002'$$,
  '23514',
  'birth_date cannot be cleared',
  'a birth date cannot be removed'
);

-- Location sharing ------------------------------------------------------------

select throws_ok(
  $$update public.user_settings set location_mode = 'foreground'
    where user_id = '00000000-0000-0000-0000-000000000001'$$,
  '23514',
  'the profile must be complete to share a location',
  'an incomplete profile cannot share a location'
);

update public.profiles
set display_name = 'Bob', gender = 'man', avatar_path = 'bob.jpg'
where id = '00000000-0000-0000-0000-000000000002';

select is(
  (select is_complete from public.profiles
   where id = '00000000-0000-0000-0000-000000000002'),
  true,
  'a profile with all required fields is complete'
);
select lives_ok(
  $$update public.user_settings set location_mode = 'foreground'
    where user_id = '00000000-0000-0000-0000-000000000002'$$,
  'a complete profile can share a location'
);

-- Access from the app ---------------------------------------------------------

select pg_temp.act_as('00000000-0000-0000-0000-000000000001');

select is(
  (select count(*)::int from public.profiles),
  1,
  'a user only sees their own profile'
);
select is(
  (select count(*)::int from public.user_settings),
  1,
  'a user only sees their own settings'
);
select lives_ok(
  $$update public.profiles set bio = 'Hello'
    where id = '00000000-0000-0000-0000-000000000001'$$,
  'a user can update their own profile'
);
select lives_ok(
  $$update public.profiles set bio = 'Hacked'
    where id = '00000000-0000-0000-0000-000000000002'$$,
  'updating another profile runs without effect'
);
select throws_ok(
  $$update public.profiles set is_student_verified = true
    where id = '00000000-0000-0000-0000-000000000001'$$,
  '42501',
  null,
  'a user cannot give themselves the badge'
);
select lives_ok(
  $$update public.profiles set birth_date = '2000-01-01'
    where id = '00000000-0000-0000-0000-000000000001'$$,
  'a user can set their birth date'
);
select throws_ok(
  $$update public.profiles set birth_date = '2001-01-01'
    where id = '00000000-0000-0000-0000-000000000001'$$,
  '23514',
  'birth_date can only be set once',
  'a user cannot change their birth date afterwards'
);
select throws_ok(
  $$update public.profiles set id = gen_random_uuid()
    where id = '00000000-0000-0000-0000-000000000001'$$,
  '42501',
  null,
  'a user cannot change their id'
);
select throws_ok(
  $$insert into public.profiles (id)
    values ('00000000-0000-0000-0000-000000000009')$$,
  '42501',
  null,
  'a user cannot create a profile'
);
select throws_ok(
  $$delete from public.profiles
    where id = '00000000-0000-0000-0000-000000000001'$$,
  '42501',
  null,
  'a user cannot delete a profile'
);
select throws_ok(
  $$select * from public.university_domains$$,
  '42501',
  null,
  'university domains are not readable'
);
select throws_ok(
  $$select public.is_university_email('a@epfl.ch')$$,
  '42501',
  null,
  'server functions are not callable'
);

reset role;

select is(
  (select bio from public.profiles
   where id = '00000000-0000-0000-0000-000000000002'),
  null,
  'another profile was left unchanged'
);
select lives_ok(
  $$update public.profiles set birth_date = '2001-01-01'
    where id = '00000000-0000-0000-0000-000000000001'$$,
  'an administrator can correct a birth date'
);

-- Account deletion ------------------------------------------------------------

delete from auth.users where id = '00000000-0000-0000-0000-000000000004';

select is(
  (select count(*)::int from public.profiles
   where id = '00000000-0000-0000-0000-000000000004'),
  0,
  'deleting the account deletes the profile'
);
select is(
  (select count(*)::int from public.user_settings
   where user_id = '00000000-0000-0000-0000-000000000004'),
  0,
  'deleting the account deletes the settings'
);

select * from finish();

rollback;
