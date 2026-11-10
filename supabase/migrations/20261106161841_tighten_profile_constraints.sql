-- Limits on profile values, and the guarantee that a user who shares a location
-- always has a complete profile.
--
-- The numbers below mirror BusinessRules (business_rules.dart).

-- Limits ---------------------------------------------------------------------

alter table public.profiles
  add constraint profiles_display_name_length
    check (char_length(display_name) <= 50),
  add constraint profiles_bio_length
    check (char_length(bio) <= 500),
  add constraint profiles_occupation_length
    check (char_length(occupation) <= 100),
  add constraint profiles_university_length
    check (char_length(university) <= 100);

alter table public.user_settings
  add constraint user_settings_detection_radius_max
    check (detection_radius_m <= 5000);

-- Birth date -----------------------------------------------------------------

-- Same rules as before, with a maximum age to catch typing mistakes.
create or replace function public.check_birth_date()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.birth_date is null and old.birth_date is not null then
    raise exception 'birth_date cannot be cleared'
      using errcode = 'check_violation';
  end if;

  -- Users can correct it once, for example after a typing mistake. After that,
  -- only an administrator, with a server role, can change it.
  --
  -- A security definer function does not run as "authenticated": one that lets
  -- users change their birth date would bypass this rule.
  if old.birth_date is not null
    and new.birth_date <> old.birth_date
    and current_user = 'authenticated' then
    if old.birth_date_corrected then
      raise exception 'birth_date can only be corrected once'
        using errcode = 'check_violation';
    end if;

    new.birth_date_corrected := true;
  end if;

  -- Keep the 18 in sync with BusinessRules.minimumAge.
  if new.birth_date > (current_date - interval '18 years')::date then
    raise exception 'the user is under the minimum age'
      using errcode = 'check_violation';
  end if;

  -- Keep the 120 in sync with BusinessRules.maximumAge.
  if new.birth_date < (current_date - interval '120 years')::date then
    raise exception 'the user is over the maximum age'
      using errcode = 'check_violation';
  end if;

  return new;
end;
$$;

-- Complete profiles ----------------------------------------------------------

-- Users can replace a required field, but not empty it. Administrators can, for
-- example to remove an inappropriate photo.
create function public.check_required_profile_fields()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if current_user = 'authenticated' and (
    (new.display_name is null and old.display_name is not null)
    or (new.gender is null and old.gender is not null)
    or (new.avatar_path is null and old.avatar_path is not null)
  ) then
    raise exception 'required profile fields cannot be cleared'
      using errcode = 'check_violation';
  end if;

  return new;
end;
$$;

create trigger check_profile_required_fields
  before update of display_name, gender, avatar_path on public.profiles
  for each row
  execute function public.check_required_profile_fields();

-- A profile that becomes incomplete stops sharing its location.
create function public.hide_incomplete_profile()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.user_settings
  set location_mode = 'invisible'
  where user_id = new.id;

  return new;
end;
$$;

create trigger on_profile_became_incomplete
  after update on public.profiles
  for each row
  when (old.is_complete and not new.is_complete)
  execute function public.hide_incomplete_profile();

-- These functions only run through triggers: they are not callable from the
-- app, where they would otherwise be exposed as RPC.
revoke all on function public.check_required_profile_fields()
  from public, anon, authenticated;
revoke all on function public.hide_incomplete_profile()
  from public, anon, authenticated;
