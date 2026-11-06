-- Profiles, user settings and the university domains behind the student badge.
--
-- Rows are created by triggers on auth.users, never by the app. Column grants
-- complete Row Level Security, which can only allow or refuse a whole row.

-- Tables ---------------------------------------------------------------------

create type public.location_mode as enum ('invisible', 'foreground', 'background');

create table public.university_domains (
  domain text primary key
    check (domain ~ '^[a-z0-9-]+(\.[a-z0-9-]+)+$')
);

-- Provisional list: add a migration to change it.
insert into public.university_domains (domain)
values ('epfl.ch'), ('unil.ch');

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text check (btrim(display_name) <> ''),
  birth_date date,
  gender text check (gender in ('woman', 'man', 'other')),
  bio text,
  occupation text,
  university text,
  is_student_verified boolean not null default false,
  avatar_path text check (btrim(avatar_path) <> ''),
  -- Required fields are empty until onboarding: features that expose a user
  -- must require this flag, so that an empty birth date cannot bypass the
  -- minimum age.
  is_complete boolean generated always as (
    display_name is not null
    and birth_date is not null
    and gender is not null
    and avatar_path is not null
  ) stored,
  created_at timestamptz not null default now()
);

create table public.user_settings (
  user_id uuid primary key references auth.users (id) on delete cascade,
  location_mode public.location_mode not null default 'invisible',
  -- Default of BusinessRules.defaultDetectionRadiusMeters.
  detection_radius_m integer not null default 100
    check (detection_radius_m > 0),
  pref_genders text[] not null default array['woman', 'man', 'other']
    check (pref_genders <@ array['woman', 'man', 'other']),
  -- Minimum of BusinessRules.minimumAge.
  pref_age_min integer not null default 18
    check (pref_age_min >= 18),
  pref_age_max integer
    check (pref_age_max >= pref_age_min),
  notification_prefs jsonb not null default '{}'
);

-- Access ---------------------------------------------------------------------

alter table public.university_domains enable row level security;
alter table public.profiles enable row level security;
alter table public.user_settings enable row level security;

revoke all on public.university_domains from anon, authenticated;
revoke all on public.profiles from anon, authenticated;
revoke all on public.user_settings from anon, authenticated;

grant select on public.profiles to authenticated;
grant update (
  display_name, birth_date, gender, bio, occupation, university, avatar_path
) on public.profiles to authenticated;

grant select on public.user_settings to authenticated;
grant update (
  location_mode, detection_radius_m, pref_genders, pref_age_min, pref_age_max,
  notification_prefs
) on public.user_settings to authenticated;

-- Only read by the server, through the triggers below.
create policy "University domains are not accessible from the app"
  on public.university_domains for all
  to anon, authenticated
  using (false)
  with check (false);

create policy "Users can read their own profile"
  on public.profiles for select
  to authenticated
  using ((select auth.uid()) = id);

create policy "Users can update their own profile"
  on public.profiles for update
  to authenticated
  using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);

create policy "Users can read their own settings"
  on public.user_settings for select
  to authenticated
  using ((select auth.uid()) = user_id);

create policy "Users can update their own settings"
  on public.user_settings for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

-- Student badge --------------------------------------------------------------

-- True when the domain of the email is a listed domain or one of its
-- subdomains: students.unil.ch matches unil.ch, fakeunil.ch does not.
create function public.is_university_email(email text)
returns boolean
language sql
stable
set search_path = ''
as $$
  select exists (
    select 1
    from public.university_domains as listed
    cross join lateral (
      select lower(split_part(email, '@', -1)) as domain
    ) as candidate
    where candidate.domain = listed.domain
      or right(candidate.domain, length(listed.domain) + 1)
        = '.' || listed.domain
  );
$$;

-- The auth.users row exists as soon as a code is sent, before the address is
-- proven: the badge requires a confirmed email.
create function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, is_student_verified)
  values (
    new.id,
    new.email_confirmed_at is not null
      and public.is_university_email(new.email)
  );

  insert into public.user_settings (user_id)
  values (new.id);

  return new;
end;
$$;

create function public.sync_student_badge()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.profiles
  set is_student_verified = new.email_confirmed_at is not null
    and public.is_university_email(new.email)
  where id = new.id;

  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row
  execute function public.handle_new_user();

create trigger on_auth_user_email_changed
  after update of email, email_confirmed_at on auth.users
  for each row
  when (
    old.email is distinct from new.email
    or old.email_confirmed_at is distinct from new.email_confirmed_at
  )
  execute function public.sync_student_badge();

-- Minimum age ----------------------------------------------------------------

-- A trigger rather than a CHECK constraint, whose result must not depend on
-- the current date.
create function public.check_birth_date()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.birth_date is null and old.birth_date is not null then
    raise exception 'birth_date cannot be cleared'
      using errcode = 'check_violation';
  end if;

  -- Users set it once. Only an administrator, with a server role, can correct
  -- it afterwards.
  if old.birth_date is not null
    and new.birth_date <> old.birth_date
    and current_user = 'authenticated' then
    raise exception 'birth_date can only be set once'
      using errcode = 'check_violation';
  end if;

  -- Keep the 18 in sync with BusinessRules.minimumAge (business_rules.dart).
  if new.birth_date > (current_date - interval '18 years')::date then
    raise exception 'the user is under the minimum age'
      using errcode = 'check_violation';
  end if;

  return new;
end;
$$;

create trigger check_profile_birth_date
  before update of birth_date on public.profiles
  for each row
  execute function public.check_birth_date();

-- Location sharing -----------------------------------------------------------

-- Users stay invisible until their profile, and so their age, is complete.
create function public.check_location_mode()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.location_mode <> 'invisible' and not exists (
    select 1
    from public.profiles
    where id = new.user_id
      and is_complete
  ) then
    raise exception 'the profile must be complete to share a location'
      using errcode = 'check_violation';
  end if;

  return new;
end;
$$;

create trigger check_settings_location_mode
  before update of location_mode on public.user_settings
  for each row
  execute function public.check_location_mode();

-- These functions only run through triggers: they are not callable from the
-- app, where they would otherwise be exposed as RPC.
revoke all on function public.is_university_email(text)
  from public, anon, authenticated;
revoke all on function public.handle_new_user()
  from public, anon, authenticated;
revoke all on function public.sync_student_badge()
  from public, anon, authenticated;
revoke all on function public.check_birth_date()
  from public, anon, authenticated;
revoke all on function public.check_location_mode()
  from public, anon, authenticated;
