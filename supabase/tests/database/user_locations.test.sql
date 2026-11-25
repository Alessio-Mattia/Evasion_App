begin;

create extension if not exists pgtap with schema extensions;

select plan(20);

-- Fixtures --------------------------------------------------------------------
-- Alice and Bob have complete profiles; Alice shares her location, Bob is
-- invisible. Carol's profile is incomplete. Positions are around the EPFL:
-- 0.009 degree of latitude is about 1 km.

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

-- Moves Alice's latest report back in time by age.
create function pg_temp.age_alice_location(age interval)
returns void
language sql
as $$
  update public.user_locations
  set recorded_at = recorded_at - age
  where user_id = '00000000-0000-0000-0000-000000000001';
$$;

insert into auth.users (id, email, email_confirmed_at) values
  ('00000000-0000-0000-0000-000000000001', 'alice@example.com', now()),
  ('00000000-0000-0000-0000-000000000002', 'bob@example.com', now()),
  ('00000000-0000-0000-0000-000000000003', 'carol@example.com', now());

insert into storage.objects (bucket_id, name, owner_id, metadata)
select 'avatars', id::text || '/a.jpg', id, '{"mimetype": "image/jpeg"}'
from auth.users;

update public.profiles
set display_name = 'User', gender = 'other', birth_date = '2000-01-01',
  avatar_path = id::text || '/a.jpg'
where id <> '00000000-0000-0000-0000-000000000003';

update public.user_settings set location_mode = 'foreground'
where user_id = '00000000-0000-0000-0000-000000000001';

-- Reporting -------------------------------------------------------------------

select pg_temp.act_as('00000000-0000-0000-0000-000000000001');

select is(
  public.report_location(46.5191, 6.5668, 12),
  true,
  'a user sharing their location can report it'
);
select is(
  public.report_location(46.5192, 6.5668, 12),
  false,
  'a report within 30 seconds of the previous one is not kept'
);

reset role;

select results_eq(
  $$select round(extensions.st_y(geog::extensions.geometry)::numeric, 4),
      accuracy_m, is_moving_fast
    from public.user_locations
    where user_id = '00000000-0000-0000-0000-000000000001'$$,
  $$values (46.5191::numeric, 12::real, false)$$,
  'the first position is kept, as reported'
);

select pg_temp.age_alice_location(interval '1 minute');
select pg_temp.act_as('00000000-0000-0000-0000-000000000001');

select is(
  public.report_location(46.5191, 6.5668, 150),
  false,
  'a position more imprecise than 100 m is not kept'
);
select is(
  public.report_location(46.5191 + 0.018, 6.5668, 10),
  true,
  'a position 2 km away a minute later is kept'
);

reset role;

select is(
  (select is_moving_fast from public.user_locations
   where user_id = '00000000-0000-0000-0000-000000000001'),
  true,
  '2 km in a minute is faster than 50 km/h: in a vehicle'
);

select pg_temp.age_alice_location(interval '5 minutes');
select pg_temp.act_as('00000000-0000-0000-0000-000000000001');
select public.report_location(46.5191 + 0.019, 6.5668, 10);
reset role;

select is(
  (select is_moving_fast from public.user_locations
   where user_id = '00000000-0000-0000-0000-000000000001'),
  false,
  '100 m in 5 minutes is walking'
);
select is(
  (select count(*)::int from public.user_locations),
  1,
  'only the latest position of a user is kept'
);

select pg_temp.act_as('00000000-0000-0000-0000-000000000001');

select throws_ok(
  'select public.report_location(91, 6.5668, 10)',
  '23514', null, 'coordinates out of range are refused'
);
select throws_ok(
  'select public.report_location(46.5191, 6.5668, null)',
  '23514', null, 'a position needs an accuracy'
);

-- Who may report --------------------------------------------------------------

select pg_temp.act_as('00000000-0000-0000-0000-000000000002');

select throws_ok(
  'select public.report_location(46.5191, 6.5668, 10)',
  '42501', 'the user does not share their location',
  'an invisible user cannot report a position'
);

select pg_temp.act_as('00000000-0000-0000-0000-000000000003');

select throws_ok(
  'select public.report_location(46.5191, 6.5668, 10)',
  '42501', 'the user does not share their location',
  'a user with an incomplete profile cannot report a position'
);

reset role;

select ok(
  not has_function_privilege(
    'anon',
    'public.report_location(double precision, double precision,
      double precision)',
    'execute'
  ),
  'signed-out users cannot report a position'
);

-- Nobody reads positions ------------------------------------------------------

select pg_temp.act_as('00000000-0000-0000-0000-000000000001');

select throws_ok(
  'select * from public.user_locations',
  '42501', null, 'a user cannot read positions, not even their own'
);
select throws_ok(
  $$insert into public.user_locations (user_id, geog, accuracy_m)
    values ('00000000-0000-0000-0000-000000000001',
            'POINT(6.5668 46.5191)', 5)$$,
  '42501', null, 'a user cannot write a position directly'
);

-- Turning invisible -----------------------------------------------------------

update public.user_settings set location_mode = 'invisible'
where user_id = '00000000-0000-0000-0000-000000000001';

reset role;

select is(
  (select count(*)::int from public.user_locations),
  0,
  'turning invisible deletes the position at once'
);

-- Purge -----------------------------------------------------------------------

update public.user_settings set location_mode = 'foreground'
where user_id in ('00000000-0000-0000-0000-000000000001',
                  '00000000-0000-0000-0000-000000000002');

select pg_temp.act_as('00000000-0000-0000-0000-000000000001');
select public.report_location(46.5191, 6.5668, 10);
select pg_temp.act_as('00000000-0000-0000-0000-000000000002');
select public.report_location(46.5191, 6.5668, 10);
reset role;

select pg_temp.age_alice_location(interval '25 hours');
select private.purge_old_locations();

select is(
  (select array_agg(user_id) from public.user_locations),
  array['00000000-0000-0000-0000-000000000002']::uuid[],
  'the purge deletes the positions older than 24 hours only'
);
select is(
  (select schedule from cron.job where jobname = 'purge-old-locations'),
  '*/15 * * * *',
  'the purge runs every 15 minutes'
);

-- Account deletion ------------------------------------------------------------

delete from auth.users where id = '00000000-0000-0000-0000-000000000002';

select is(
  (select count(*)::int from public.user_locations),
  0,
  'deleting an account deletes its position'
);
select ok(
  (select relrowsecurity from pg_class
   where oid = 'public.user_locations'::regclass),
  'row level security is enabled on user_locations'
);

select * from finish();

rollback;
