begin;

create extension if not exists pgtap with schema extensions;

select plan(12);

-- Fixtures --------------------------------------------------------------------
-- Alice has a complete profile, so that she may share her location.

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
  ('avatars', '00000000-0000-0000-0000-000000000001/a.jpg',
   '00000000-0000-0000-0000-000000000001', '{"mimetype": "image/jpeg"}'),
  ('profile-photos', '00000000-0000-0000-0000-000000000001/p.jpg',
   '00000000-0000-0000-0000-000000000001', '{"mimetype": "image/jpeg"}');

update public.profiles
set display_name = 'Alice', gender = 'woman', birth_date = '2000-01-01',
  avatar_path = id::text || '/a.jpg'
where id = '00000000-0000-0000-0000-000000000001';

select pg_temp.act_as('00000000-0000-0000-0000-000000000001');

-- Location mode ---------------------------------------------------------------

select lives_ok(
  $$update public.user_settings set location_mode = 'foreground'
    where user_id = '00000000-0000-0000-0000-000000000001'$$,
  'sharing the location while the app is open is accepted'
);
select throws_ok(
  $$update public.user_settings set location_mode = 'background'
    where user_id = '00000000-0000-0000-0000-000000000001'$$,
  '23514', null, 'background sharing is refused until it ships'
);

-- Genders ---------------------------------------------------------------------

select lives_ok(
  $$update public.user_settings set pref_genders = array['woman']
    where user_id = '00000000-0000-0000-0000-000000000001'$$,
  'a single gender is accepted'
);
select throws_ok(
  $$update public.user_settings set pref_genders = array[]::text[]
    where user_id = '00000000-0000-0000-0000-000000000001'$$,
  '23514', null, 'an empty list of genders is refused'
);

-- Ages ------------------------------------------------------------------------

select lives_ok(
  $$update public.user_settings set pref_age_max = 120
    where user_id = '00000000-0000-0000-0000-000000000001'$$,
  'a maximum age of 120 is accepted'
);
select throws_ok(
  $$update public.user_settings set pref_age_max = 121
    where user_id = '00000000-0000-0000-0000-000000000001'$$,
  '23514', null, 'a maximum age over 120 is refused'
);
select throws_ok(
  $$update public.user_settings set pref_age_min = 121, pref_age_max = null
    where user_id = '00000000-0000-0000-0000-000000000001'$$,
  '23514', null, 'a minimum age over 120 is refused'
);
select lives_ok(
  $$update public.user_settings set pref_age_max = null
    where user_id = '00000000-0000-0000-0000-000000000001'$$,
  'no maximum age is still accepted'
);

-- Captions --------------------------------------------------------------------

select lives_ok(
  $$insert into public.profile_pages (position, type, content, image_path)
    values (1, 'photo', '{}', '00000000-0000-0000-0000-000000000001/p.jpg')$$,
  'a photo page without caption is accepted'
);
select lives_ok(
  $$update public.profile_pages set content = '{"caption": "Summer"}'
    where position = 1$$,
  'a caption is accepted'
);
select throws_ok(
  $$update public.profile_pages set content = '{"caption": ""}'
    where position = 1$$,
  '23514', null, 'an empty caption is refused'
);
select throws_ok(
  $$update public.profile_pages set content = '{"caption": "   "}'
    where position = 1$$,
  '23514', null, 'a caption made of spaces is refused'
);

select * from finish();

rollback;
