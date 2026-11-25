-- Crossings: two people who were near each other at the same time.
--
-- The phone reports its position with report_location; the server compares
-- it with the latest positions of the others and records a crossing when
-- both:
--   - shared their location (not invisible), with complete profiles, and
--     did not block each other;
--   - reported positions at most 3 minutes apart (the other's latest one is
--     at most that old), none of them moving faster than 50 km/h;
--   - were within the smaller of their two detection radii;
--   - match each other's criteria: gender and age range, both ways.
--
-- A pair gets at most one crossing per hour, and crossings are kept a week.
-- Users only read their own through my_crossings, with the time rounded to
-- the half hour and a zone, never a precise point. The zone is the cell
-- holding the midpoint of the two positions, at least as large as the radius
-- that made the crossing: it never tells more than the crossing itself, so
-- a 5 km radius cannot reveal where the other was within 100 m.
--
-- The numbers below mirror BusinessRules (business_rules.dart); they are
-- provisional until the release.

-- Grid -----------------------------------------------------------------------

-- Centre of the grid cell of about cell_size metres on each side holding
-- point: cell_size metres of latitude, and as many degrees of longitude as
-- make cell_size metres at the latitude of the cell's centre. The same point
-- always gives the same centre.
create function private.grid_point(point extensions.geography,
  cell_size double precision)
returns extensions.geography
language sql
immutable
set search_path = ''
as $$
  with cell_row as (
    select
      (floor(extensions.st_y(point::extensions.geometry) / size) + 0.5)
        * size as latitude,
      extensions.st_x(point::extensions.geometry) as longitude,
      size
    from (select cell_size / 111320.0 as size) as cell
  ),
  cell as (
    select latitude, longitude, size / cos(radians(latitude)) as width
    from cell_row
  )
  select extensions.st_setsrid(
    extensions.st_makepoint(
      (floor(longitude / width) + 0.5) * width,
      latitude
    ),
    4326
  )::extensions.geography
  from cell;
$$;

-- Posts keep their cells of 300 m (BusinessRules.postFuzzyCellSizeMeters),
-- now drawn by grid_point: the same result, one implementation.
create or replace function private.fuzzy_point(point extensions.geography)
returns extensions.geography
language sql
immutable
set search_path = ''
as $$
  select private.grid_point(point, 300);
$$;

revoke all on function
  private.grid_point(extensions.geography, double precision) from public;

-- Table ----------------------------------------------------------------------

create table public.crossings (
  id uuid primary key default gen_random_uuid(),
  user_a uuid not null references auth.users (id) on delete cascade,
  user_b uuid not null references auth.users (id) on delete cascade,
  crossed_at timestamptz not null default now(),
  -- Centre of the cell holding the midpoint of the two positions, as large
  -- as the radius that made the crossing and at least 100 m
  -- (BusinessRules.crossingZoneCellSizeMeters): never a precise point.
  zone extensions.geography(Point, 4326) not null,
  -- A pair is stored once, whoever reported.
  check (user_a < user_b)
);

create index crossings_user_a_idx on public.crossings (user_a, crossed_at);
create index crossings_user_b_idx on public.crossings (user_b, crossed_at);
create index crossings_crossed_at_idx on public.crossings (crossed_at);

alter table public.crossings enable row level security;

revoke all on public.crossings from anon, authenticated;

-- Read through my_crossings only, which rounds the time and hides what the
-- user may no longer see.
create policy "Crossings are not accessible from the app"
  on public.crossings for all
  to anon, authenticated
  using (false)
  with check (false);

-- Detection ------------------------------------------------------------------

-- Age in whole years, as get_public_profile shows it.
create function private.age_of(birth_date date)
returns integer
language sql
stable
set search_path = ''
as $$
  select extract(year from age(current_date, birth_date))::integer;
$$;

revoke all on function private.age_of(date) from public;

-- Records the crossings of reporter with everyone near them, from their
-- latest positions. Called by report_location, never by the app.
create function private.detect_crossings(reporter uuid)
returns void
language sql
security definer
set search_path = ''
as $$
  insert into public.crossings (user_a, user_b, zone)
  select
    least(reporter, other.user_id),
    greatest(reporter, other.user_id),
    private.grid_point(
      -- The midpoint: the two positions are at most 5 km apart, so their
      -- plain average in degrees is close enough.
      extensions.st_centroid(
        extensions.st_collect(
          mine.geog::extensions.geometry,
          other.geog::extensions.geometry
        )
      )::extensions.geography,
      greatest(
        100,
        least(my_settings.detection_radius_m, other_settings.detection_radius_m)
      )
    )
  from public.user_locations as mine
  join public.user_settings as my_settings
    on my_settings.user_id = mine.user_id
  join public.profiles as me on me.id = mine.user_id
  join public.user_locations as other
    on other.user_id <> mine.user_id
    -- A first cut with the largest radius allowed
    -- (BusinessRules.maxDetectionRadiusMeters), which the spatial index
    -- answers quickly; the real radii are checked below.
    and extensions.st_dwithin(mine.geog, other.geog, 5000)
  join public.user_settings as other_settings
    on other_settings.user_id = other.user_id
  join public.profiles as them on them.id = other.user_id
  where mine.user_id = reporter
    and not mine.is_moving_fast
    and not other.is_moving_fast
    -- BusinessRules.crossingMaxPositionAge.
    and other.recorded_at >= now() - interval '3 minutes'
    and my_settings.location_mode <> 'invisible'
    and other_settings.location_mode <> 'invisible'
    and me.is_complete
    and them.is_complete
    -- Each one is within the other's radius: the smaller of the two.
    and extensions.st_dwithin(
      mine.geog,
      other.geog,
      least(my_settings.detection_radius_m, other_settings.detection_radius_m)
    )
    -- Each one matches the other's criteria.
    and them.gender = any (my_settings.pref_genders)
    and me.gender = any (other_settings.pref_genders)
    and private.age_of(them.birth_date)
      between my_settings.pref_age_min
      and coalesce(my_settings.pref_age_max, 1000)
    and private.age_of(me.birth_date)
      between other_settings.pref_age_min
      and coalesce(other_settings.pref_age_max, 1000)
    and not private.is_blocked(reporter, other.user_id)
    -- At most one crossing per hour for a pair
    -- (BusinessRules.crossingRepeatInterval).
    and not exists (
      select 1 from public.crossings as recent
      where recent.user_a = least(reporter, other.user_id)
        and recent.user_b = greatest(reporter, other.user_id)
        and recent.crossed_at > now() - interval '1 hour'
    );
$$;

revoke all on function private.detect_crossings(uuid) from public;

-- Reporting ------------------------------------------------------------------

-- Saves the phone's position as the signed-in user's latest one, records the
-- crossings it makes, and returns whether it was kept. It is not kept,
-- without error, when it is too imprecise (accuracy over 100 m:
-- BusinessRules.locationMaxAccuracyMeters) or comes less than 30 seconds
-- after the previous one (BusinessRules.locationReportMinInterval).
--
-- A position more than 50 km/h away from the previous one
-- (BusinessRules.crossingMaxSpeedKmh) is kept, for the next speed check, but
-- creates no crossing: in a vehicle, nobody meets anyone.
--
-- Fails when the user does not share their location: invisible, or with an
-- incomplete profile.
create function public.report_location(
  latitude double precision,
  longitude double precision,
  accuracy_meters double precision
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
#variable_conflict use_variable
declare
  user_id uuid := (select auth.uid());
  reported extensions.geography;
  previous public.user_locations;
  speed_kmh double precision;
begin
  if not exists (
    select 1
    from public.user_settings as settings
    join public.profiles as profile on profile.id = settings.user_id
    where settings.user_id = user_id
      and settings.location_mode <> 'invisible'
      and profile.is_complete
  ) then
    raise exception 'the user does not share their location'
      using errcode = 'insufficient_privilege';
  end if;

  reported := private.point_from(latitude, longitude);
  if reported is null or accuracy_meters is null or accuracy_meters < 0 then
    raise exception 'a position needs coordinates and an accuracy'
      using errcode = 'check_violation';
  end if;

  if accuracy_meters > 100 then
    return false;
  end if;

  select * into previous
  from public.user_locations as location
  where location.user_id = user_id
  for update;

  if found and previous.recorded_at > now() - interval '30 seconds' then
    return false;
  end if;

  if found then
    speed_kmh := extensions.st_distance(previous.geog, reported) / 1000
      / greatest(extract(epoch from now() - previous.recorded_at), 1) * 3600;
  end if;

  insert into public.user_locations as location (
    user_id, geog, accuracy_m, is_moving_fast, recorded_at
  )
  values (
    user_id, reported, accuracy_meters, coalesce(speed_kmh > 50, false), now()
  )
  on conflict on constraint user_locations_pkey do update
  set geog = excluded.geog,
    accuracy_m = excluded.accuracy_m,
    is_moving_fast = excluded.is_moving_fast,
    recorded_at = excluded.recorded_at;

  perform private.detect_crossings(user_id);

  return true;
end;
$$;

revoke all on function public.report_location(
  double precision, double precision, double precision
) from public, anon;
grant execute on function public.report_location(
  double precision, double precision, double precision
) to authenticated;

-- Reading --------------------------------------------------------------------

-- The signed-in user's crossings of the last week, the most recent first:
-- who, and around when and where. The time is rounded to the nearest half
-- hour (BusinessRules.crossingTimeRounding), and the zone is the centre of a
-- cell at least as large as the radius of the crossing. People the user can
-- no longer see (blocked either way, or with an incomplete profile) are left
-- out, through get_public_profile.
create function public.my_crossings()
returns table (
  id uuid,
  user_id uuid,
  display_name text,
  age integer,
  avatar_path text,
  is_student_verified boolean,
  crossed_at timestamptz,
  latitude double precision,
  longitude double precision
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    crossing.id,
    person.id,
    person.display_name,
    person.age,
    person.avatar_path,
    person.is_student_verified,
    date_bin(
      interval '30 minutes',
      crossing.crossed_at + interval '15 minutes',
      timestamptz '2000-01-01 00:00:00+00'
    ),
    extensions.st_y(crossing.zone::extensions.geometry),
    extensions.st_x(crossing.zone::extensions.geometry)
  from public.crossings as crossing
  cross join lateral public.get_public_profile(
    case
      when crossing.user_a = (select auth.uid()) then crossing.user_b
      else crossing.user_a
    end
  ) as person
  where (select auth.uid()) in (crossing.user_a, crossing.user_b)
    -- BusinessRules.crossingHistory.
    and crossing.crossed_at > now() - interval '7 days'
  order by crossing.crossed_at desc
  limit 500;
$$;

revoke all on function public.my_crossings() from public, anon;
grant execute on function public.my_crossings() to authenticated;

-- Purge ----------------------------------------------------------------------

-- Deletes the crossings older than a week (BusinessRules.crossingHistory).
create function private.purge_old_crossings()
returns void
language sql
set search_path = ''
as $$
  delete from public.crossings where crossed_at < now() - interval '7 days';
$$;

revoke all on function private.purge_old_crossings() from public;

select cron.schedule(
  'purge-old-crossings',
  '0 * * * *',
  'select private.purge_old_crossings()'
);
