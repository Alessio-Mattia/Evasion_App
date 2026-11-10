begin;

create extension if not exists pgtap with schema extensions;

select plan(28);

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
  ('00000000-0000-0000-0000-000000000001', 'alice@example.com', now());

insert into storage.objects (bucket_id, name, owner_id, metadata) values
  ('avatars', '00000000-0000-0000-0000-000000000001/alice.jpg',
   '00000000-0000-0000-0000-000000000001', '{"mimetype": "image/jpeg"}'),
  ('avatars', '00000000-0000-0000-0000-000000000001/new.jpg',
   '00000000-0000-0000-0000-000000000001', '{"mimetype": "image/jpeg"}');

select pg_temp.act_as('00000000-0000-0000-0000-000000000001');

update public.profiles
set
  display_name = 'Alice',
  birth_date = '2000-01-01',
  gender = 'other',
  avatar_path = '00000000-0000-0000-0000-000000000001/alice.jpg'
where id = '00000000-0000-0000-0000-000000000001';

update public.user_settings
set location_mode = 'foreground'
where user_id = '00000000-0000-0000-0000-000000000001';

-- Required fields -------------------------------------------------------------

select throws_ok(
  $$update public.profiles set display_name = null
    where id = '00000000-0000-0000-0000-000000000001'$$,
  '23514',
  'required profile fields cannot be cleared',
  'a user cannot empty their name'
);
select throws_ok(
  $$update public.profiles set gender = null
    where id = '00000000-0000-0000-0000-000000000001'$$,
  '23514',
  'required profile fields cannot be cleared',
  'a user cannot empty their gender'
);
select throws_ok(
  $$update public.profiles set avatar_path = null
    where id = '00000000-0000-0000-0000-000000000001'$$,
  '23514',
  'required profile fields cannot be cleared',
  'a user cannot empty their photo'
);
select lives_ok(
  $$update public.profiles
    set display_name = 'Alicia', gender = 'woman', avatar_path = '00000000-0000-0000-0000-000000000001/new.jpg'
    where id = '00000000-0000-0000-0000-000000000001'$$,
  'a user can replace the required fields'
);
select is(
  (select location_mode::text from public.user_settings),
  'foreground',
  'replacing the required fields keeps the location shared'
);
select is(
  (select is_complete from public.profiles),
  true,
  'the profile is still complete'
);

-- Limits ----------------------------------------------------------------------

select lives_ok(
  format(
    $$update public.profiles set display_name = %L
      where id = '00000000-0000-0000-0000-000000000001'$$,
    repeat('a', 50)
  ),
  'a name of 50 characters is accepted'
);
select throws_ok(
  format(
    $$update public.profiles set display_name = %L
      where id = '00000000-0000-0000-0000-000000000001'$$,
    repeat('a', 51)
  ),
  '23514',
  null,
  'a name of 51 characters is refused'
);
select lives_ok(
  format(
    $$update public.profiles set bio = %L
      where id = '00000000-0000-0000-0000-000000000001'$$,
    repeat('a', 500)
  ),
  'a bio of 500 characters is accepted'
);
select throws_ok(
  format(
    $$update public.profiles set bio = %L
      where id = '00000000-0000-0000-0000-000000000001'$$,
    repeat('a', 501)
  ),
  '23514',
  null,
  'a bio of 501 characters is refused'
);
select lives_ok(
  format(
    $$update public.profiles set occupation = %L
      where id = '00000000-0000-0000-0000-000000000001'$$,
    repeat('a', 100)
  ),
  'an occupation of 100 characters is accepted'
);
select throws_ok(
  format(
    $$update public.profiles set occupation = %L
      where id = '00000000-0000-0000-0000-000000000001'$$,
    repeat('a', 101)
  ),
  '23514',
  null,
  'an occupation of 101 characters is refused'
);
select lives_ok(
  format(
    $$update public.profiles set university = %L
      where id = '00000000-0000-0000-0000-000000000001'$$,
    repeat('a', 100)
  ),
  'a university of 100 characters is accepted'
);
select throws_ok(
  format(
    $$update public.profiles set university = %L
      where id = '00000000-0000-0000-0000-000000000001'$$,
    repeat('a', 101)
  ),
  '23514',
  null,
  'a university of 101 characters is refused'
);
select lives_ok(
  $$update public.user_settings set detection_radius_m = 5000
    where user_id = '00000000-0000-0000-0000-000000000001'$$,
  'a radius of 5000 m is accepted'
);
select throws_ok(
  $$update public.user_settings set detection_radius_m = 5001
    where user_id = '00000000-0000-0000-0000-000000000001'$$,
  '23514',
  null,
  'a radius of 5001 m is refused'
);

-- Birth date ------------------------------------------------------------------

select throws_ok(
  $$update public.profiles set birth_date = '1800-01-01'
    where id = '00000000-0000-0000-0000-000000000001'$$,
  '23514',
  'the user is over the maximum age',
  'an implausible birth date is refused'
);
select throws_ok(
  $$update public.profiles
    set birth_date = (current_date - interval '120 years' - interval '1 day')::date
    where id = '00000000-0000-0000-0000-000000000001'$$,
  '23514',
  'the user is over the maximum age',
  'one day over 120 years is refused'
);
select is(
  (select birth_date_corrected from public.profiles),
  false,
  'a refused birth date does not use the correction'
);
select lives_ok(
  $$update public.profiles
    set birth_date = (current_date - interval '120 years')::date
    where id = '00000000-0000-0000-0000-000000000001'$$,
  'exactly 120 years is accepted'
);
select throws_ok(
  $$update public.profiles set birth_date = '2000-01-01'
    where id = '00000000-0000-0000-0000-000000000001'$$,
  '23514',
  'birth_date can only be corrected once',
  'the single correction still applies'
);
select throws_ok(
  $$update public.profiles
    set birth_date = (current_date - interval '10 years')::date
    where id = '00000000-0000-0000-0000-000000000001'$$,
  '23514',
  'birth_date can only be corrected once',
  'the rules on corrections still apply first'
);
select throws_ok(
  $$update public.profiles set birth_date = null
    where id = '00000000-0000-0000-0000-000000000001'$$,
  '23514',
  'birth_date cannot be cleared',
  'a birth date still cannot be removed'
);

-- Server functions ------------------------------------------------------------

select throws_ok(
  $$select public.hide_incomplete_profile()$$,
  '42501',
  null,
  'the new server functions are not callable'
);

-- Removal by an administrator -------------------------------------------------

reset role;

select lives_ok(
  $$update public.profiles set avatar_path = null
    where id = '00000000-0000-0000-0000-000000000001'$$,
  'an administrator can remove a photo'
);
select is(
  (select is_complete from public.profiles
   where id = '00000000-0000-0000-0000-000000000001'),
  false,
  'the profile becomes incomplete'
);
select is(
  (select location_mode::text from public.user_settings
   where user_id = '00000000-0000-0000-0000-000000000001'),
  'invisible',
  'an incomplete profile stops sharing its location'
);
select throws_ok(
  $$update public.profiles set birth_date = '1800-01-01'
    where id = '00000000-0000-0000-0000-000000000001'$$,
  '23514',
  'the user is over the maximum age',
  'the maximum age also applies to an administrator'
);

select * from finish();

rollback;
