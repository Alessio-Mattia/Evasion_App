begin;

create extension if not exists pgtap with schema extensions;

select plan(29);

-- Fixtures --------------------------------------------------------------------
-- Alice (woman, 26) reports her position at the EPFL. Around her:
--   Bob    (man)    20 m north, just now: the one she crosses;
--   Carol  (woman) 200 m north: beyond the 100 m radius;
--   Dave   (man)    80 m east, with a 50 m radius: the smaller one applies;
--   Eve    (woman)  20 m south, looking for men only;
--   Frank  (man)    30 m east, looking for people of 20 at most;
--   Gina   (other)  25 m west, blocked by Alice;
--   Hugo   (man)    20 m north, but his position is 4 minutes old;
--   Ivan   (man)    20 m north, but in a vehicle.
-- Everyone shares their location, with a 100 m radius unless said otherwise.

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

-- Ids by first name, readable while acting as a user, unlike auth.users.
create temp table people (name text primary key, id uuid not null);
grant select on people to authenticated;

create function pg_temp.user_id(person text)
returns uuid
language sql
as $$
  select id from people where name = person;
$$;

-- Puts the latest position of name north and east metres from the EPFL,
-- reported ago.
create function pg_temp.place(name text, north double precision,
  east double precision, ago interval default '0',
  fast boolean default false)
returns void
language sql
as $$
  insert into public.user_locations (user_id, geog, accuracy_m,
    is_moving_fast, recorded_at)
  values (
    pg_temp.user_id(name),
    private.point_from(
      46.5191 + north / 111320.0,
      6.5668 + east / (111320.0 * cos(radians(46.5191)))
    ),
    10, fast, now() - ago
  )
  on conflict (user_id) do update
  set geog = excluded.geog, is_moving_fast = excluded.is_moving_fast,
    recorded_at = excluded.recorded_at;
$$;

-- Alice reports her position at the EPFL, a minute after her previous one.
create function pg_temp.alice_reports()
returns void
language plpgsql
as $$
begin
  update public.user_locations
  set recorded_at = recorded_at - interval '1 minute'
  where user_id = pg_temp.user_id('alice');
  perform pg_temp.act_as(pg_temp.user_id('alice'));
  perform public.report_location(46.5191, 6.5668, 10);
  reset role;
end;
$$;

-- Whether Alice and name have crossed.
create function pg_temp.crossed(name text)
returns boolean
language sql
as $$
  select exists (
    select 1 from public.crossings
    where pg_temp.user_id('alice') in (user_a, user_b)
      and pg_temp.user_id(name) in (user_a, user_b)
  );
$$;

insert into people (name, id)
select name, gen_random_uuid()
from unnest(array['alice', 'bob', 'carol', 'dave', 'eve', 'frank', 'gina',
  'hugo', 'ivan']) as name;

insert into auth.users (id, email, email_confirmed_at)
select id, name || '@example.com', now() from people;

insert into storage.objects (bucket_id, name, owner_id, metadata)
select 'avatars', id::text || '/a.jpg', id, '{"mimetype": "image/jpeg"}'
from auth.users;

update public.profiles as profile
set display_name = initcap(split_part(account.email, '@', 1)),
  gender = case
    when account.email ~ '^(alice|carol|eve)@' then 'woman'
    when account.email ~ '^gina@' then 'other'
    else 'man'
  end,
  birth_date = current_date - interval '26 years 2 months',
  avatar_path = profile.id::text || '/a.jpg'
from auth.users as account
where account.id = profile.id;

update public.user_settings set location_mode = 'foreground';
update public.user_settings set detection_radius_m = 50
where user_id = pg_temp.user_id('dave');
update public.user_settings set pref_genders = array['man']
where user_id = pg_temp.user_id('eve');
update public.user_settings set pref_age_max = 20
where user_id = pg_temp.user_id('frank');

insert into public.blocks (blocker_id, blocked_id)
values (pg_temp.user_id('alice'), pg_temp.user_id('gina'));

select pg_temp.place('alice', 0, 0, interval '1 minute');
select pg_temp.place('bob', 20, 0);
select pg_temp.place('carol', 200, 0);
select pg_temp.place('dave', 0, 80);
select pg_temp.place('eve', -20, 0);
select pg_temp.place('frank', 0, 30);
select pg_temp.place('gina', 0, -25);
select pg_temp.place('hugo', 20, 0, interval '4 minutes');
select pg_temp.place('ivan', 20, 0, interval '0', true);

select pg_temp.alice_reports();

-- Detection -------------------------------------------------------------------

select ok(pg_temp.crossed('bob'), 'two compatible people close by cross');
select is(
  (select count(*)::int from public.crossings),
  1,
  'Alice crosses nobody else'
);
select ok(
  (select user_a < user_b from public.crossings),
  'a pair is stored with user_a < user_b'
);
select ok(not pg_temp.crossed('carol'), 'nobody beyond the radius');
select ok(
  not pg_temp.crossed('dave'),
  'the smaller of the two radii applies'
);
select ok(
  not pg_temp.crossed('eve'),
  'the other''s gender criteria must match'
);
select ok(
  not pg_temp.crossed('frank'),
  'the other''s age criteria must match'
);
select ok(not pg_temp.crossed('gina'), 'nobody blocked, in either direction');
select ok(
  not pg_temp.crossed('hugo'),
  'a position older than 3 minutes is too old'
);
select ok(not pg_temp.crossed('ivan'), 'nobody in a vehicle');
select ok(
  (select zone = private.grid_point(
     private.point_from(46.5191 + 10 / 111320.0, 6.5668), 100)
   from public.crossings),
  'the zone is the 100 m cell of the midpoint, not a position'
);

-- Repeats ---------------------------------------------------------------------

select pg_temp.place('bob', 20, 0);
select pg_temp.alice_reports();

select is(
  (select count(*)::int from public.crossings),
  1,
  'a pair crosses at most once an hour'
);

update public.crossings set crossed_at = crossed_at - interval '61 minutes';
select pg_temp.place('bob', 20, 0);
select pg_temp.alice_reports();

select is(
  (select count(*)::int from public.crossings),
  2,
  'an hour later, the pair can cross again'
);

update public.crossings set crossed_at = crossed_at - interval '61 minutes';
update public.user_settings set location_mode = 'invisible'
where user_id = pg_temp.user_id('bob');
select pg_temp.alice_reports();

select is(
  (select count(*)::int from public.crossings),
  2,
  'a user who turned invisible is not crossed'
);

update public.user_settings set location_mode = 'foreground'
where user_id = pg_temp.user_id('bob');
delete from public.crossings
where crossed_at < (select max(crossed_at) from public.crossings);

-- Reading ---------------------------------------------------------------------

-- The crossing happened 12 minutes past the hour: shown on the hour.
update public.crossings
set crossed_at = date_trunc('hour', now()) - interval '1 hour 48 minutes';

select pg_temp.act_as(pg_temp.user_id('alice'));

select results_eq(
  'select display_name, age, crossed_at from public.my_crossings()',
  $$values ('Bob', 26,
            date_trunc('hour', now()) - interval '2 hours')$$,
  'a user reads who they crossed, the time rounded to the half hour'
);

reset role;
update public.crossings
set crossed_at = date_trunc('hour', now()) - interval '1 hour 40 minutes';

-- The zone, read before acting as Alice, who cannot read crossings.
create temp table expected_zone as
select extensions.st_y(zone::extensions.geometry) as latitude,
  extensions.st_x(zone::extensions.geometry) as longitude
from public.crossings;
grant select on expected_zone to authenticated;

select pg_temp.act_as(pg_temp.user_id('alice'));

select is(
  (select crossed_at from public.my_crossings()),
  date_trunc('hour', now()) - interval '1 hour 30 minutes',
  '20 minutes past the hour is shown at half past'
);
select results_eq(
  $$select latitude, longitude from public.my_crossings()$$,
  'select latitude, longitude from expected_zone',
  'the place shown is the zone of the crossing'
);
select isnt(
  (select round(latitude::numeric, 4) from public.my_crossings()),
  46.5191::numeric,
  'the place shown is not the precise point'
);

select pg_temp.act_as(pg_temp.user_id('bob'));

select is(
  (select display_name from public.my_crossings()),
  'Alice',
  'both people see the crossing'
);

select pg_temp.act_as(pg_temp.user_id('carol'));

select is_empty(
  'select * from public.my_crossings()',
  'a user does not see the crossings of others'
);
select throws_ok(
  'select * from public.crossings',
  '42501', null, 'crossings cannot be read directly'
);

reset role;
insert into public.blocks (blocker_id, blocked_id)
values (pg_temp.user_id('bob'), pg_temp.user_id('alice'));
select pg_temp.act_as(pg_temp.user_id('alice'));

select is_empty(
  'select * from public.my_crossings()',
  'a block hides past crossings at once, for the blocked user too'
);

reset role;

select ok(
  not has_function_privilege('anon', 'public.my_crossings()', 'execute'),
  'signed-out users cannot read crossings'
);

-- History ---------------------------------------------------------------------

delete from public.blocks where blocker_id = pg_temp.user_id('bob');
update public.crossings set crossed_at = now() - interval '8 days';

select pg_temp.act_as(pg_temp.user_id('alice'));

select is_empty(
  'select * from public.my_crossings()',
  'crossings older than a week are not shown'
);

reset role;
select private.purge_old_crossings();

select is(
  (select count(*)::int from public.crossings),
  0,
  'the purge deletes the crossings older than a week'
);
select is(
  (select schedule from cron.job where jobname = 'purge-old-crossings'),
  '0 * * * *',
  'the purge runs every hour'
);
select ok(
  (select private.fuzzy_point(point) = private.grid_point(point, 300)
   from (select private.point_from(46.5191, 6.5668) as point) as p),
  'posts keep their 300 m cells'
);

-- Large radii -----------------------------------------------------------------
-- With 5 km radii, Alice and Carol, 200 m apart, cross. The zone must not
-- tell Carol where Alice was within 100 m: it is a 5 km cell.

update public.user_settings set detection_radius_m = 5000
where user_id in (pg_temp.user_id('alice'), pg_temp.user_id('carol'));
select pg_temp.place('carol', 200, 0);
select pg_temp.alice_reports();

select ok(pg_temp.crossed('carol'), 'with 5 km radii, 200 m is a crossing');
select ok(
  (select zone = private.grid_point(
     private.point_from(46.5191 + 100 / 111320.0, 6.5668), 5000)
   from public.crossings),
  'the zone is as large as the radius of the crossing'
);

select * from finish();

rollback;
