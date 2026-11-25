-- The latest position of each user who shares it, for crossing detection.
--
-- Only the latest position is kept: no trail of the user's moves. Nobody can
-- read it, not even its owner: the server alone compares positions. It is
-- written only through report_location (migration create_crossings),
-- deleted as soon as the user turns invisible, and purged after 24 hours
-- (BusinessRules.rawLocationRetention, provisional until the release).

-- Table ----------------------------------------------------------------------

create table public.user_locations (
  user_id uuid primary key references auth.users (id) on delete cascade,
  geog extensions.geography(Point, 4326) not null,
  -- Radius of the phone's uncertainty, in metres.
  accuracy_m real not null check (accuracy_m >= 0),
  -- Moving faster than 50 km/h since the previous report: in a vehicle,
  -- where nobody meets anyone. The position is kept, for the next speed
  -- check, but creates no crossing.
  is_moving_fast boolean not null default false,
  recorded_at timestamptz not null default now()
);

create index user_locations_geog_idx on public.user_locations
  using gist (geog);
create index user_locations_recorded_at_idx on public.user_locations
  (recorded_at);

alter table public.user_locations enable row level security;

revoke all on public.user_locations from anon, authenticated;

create policy "Locations are not accessible from the app"
  on public.user_locations for all
  to anon, authenticated
  using (false)
  with check (false);

-- Turning invisible ----------------------------------------------------------

-- Forgets the position at once when the user turns invisible, also when an
-- incomplete profile turns them invisible (hide_incomplete_profile).
create function public.forget_location_when_invisible()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  delete from public.user_locations where user_id = new.user_id;
  return new;
end;
$$;

create trigger on_location_mode_invisible
  after update of location_mode on public.user_settings
  for each row
  when (new.location_mode = 'invisible')
  execute function public.forget_location_when_invisible();

revoke all on function public.forget_location_when_invisible()
  from public, anon, authenticated;

-- Purge ----------------------------------------------------------------------

-- Deletes the positions older than 24 hours. pg_cron was enabled by
-- schedule_post_expiry.
create function private.purge_old_locations()
returns void
language sql
set search_path = ''
as $$
  delete from public.user_locations
  where recorded_at < now() - interval '24 hours';
$$;

revoke all on function private.purge_old_locations() from public;

select cron.schedule(
  'purge-old-locations',
  '*/15 * * * *',
  'select private.purge_old_locations()'
);
