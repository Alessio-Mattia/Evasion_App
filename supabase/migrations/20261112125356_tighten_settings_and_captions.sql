-- Small gaps found in review: values the app never sends, but that a direct
-- API call could store.

-- Background sharing is planned after the MVP, with its own permission and
-- licence: refused until then. Drop this constraint when it ships.
alter table public.user_settings
  add constraint user_settings_no_background_yet
    check (location_mode <> 'background');

-- An empty list would mean meeting nobody.
alter table public.user_settings
  add constraint user_settings_pref_genders_not_empty
    check (cardinality(pref_genders) >= 1);

-- Keep the 120 in sync with BusinessRules.maximumAge, as for birth dates.
alter table public.user_settings
  add constraint user_settings_pref_ages_max
    check (pref_age_min <= 120 and pref_age_max <= 120);

-- Like a text page, a caption is either absent or not blank.
alter table public.profile_pages
  add constraint profile_pages_caption_not_blank
    check (
      content -> 'caption' is null
      or btrim(content ->> 'caption') <> ''
    );
