begin;

create extension if not exists pgtap with schema extensions;

select plan(19);

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
  ('00000000-0000-0000-0000-000000000002', 'bob@example.com', now());

insert into storage.objects (bucket_id, name, owner_id, metadata) values
  ('avatars', '00000000-0000-0000-0000-000000000002/bob.jpg',
   '00000000-0000-0000-0000-000000000002', '{"mimetype": "image/jpeg"}');

-- Bucket ----------------------------------------------------------------------

select is(
  (select public from storage.buckets where id = 'avatars'),
  false,
  'the avatars bucket is private'
);
select is(
  (select file_size_limit from storage.buckets where id = 'avatars'),
  5242880::bigint,
  'photos are limited to 5 MB'
);
select is(
  (select allowed_mime_types from storage.buckets where id = 'avatars'),
  array['image/jpeg', 'image/png', 'image/webp'],
  'only JPEG, PNG and WebP are accepted'
);

-- Own folder ------------------------------------------------------------------

select pg_temp.act_as('00000000-0000-0000-0000-000000000001');

select lives_ok(
  $$insert into storage.objects (bucket_id, name, owner_id, metadata)
    values ('avatars', '00000000-0000-0000-0000-000000000001/alice.jpg',
            '00000000-0000-0000-0000-000000000001',
            '{"mimetype": "image/jpeg"}')$$,
  'a user can upload to their own folder'
);
select throws_ok(
  $$insert into storage.objects (bucket_id, name, owner_id, metadata)
    values ('avatars', '00000000-0000-0000-0000-000000000001/fake.jpg',
            '00000000-0000-0000-0000-000000000001',
            '{"mimetype": "image/png"}')$$,
  '42501',
  null,
  'the extension must match the declared format'
);
select throws_ok(
  $$insert into storage.objects (bucket_id, name, owner_id, metadata)
    values ('avatars', '00000000-0000-0000-0000-000000000001/photo',
            '00000000-0000-0000-0000-000000000001',
            '{"mimetype": "image/jpeg"}')$$,
  '42501',
  null,
  'a photo needs an extension'
);
select is(
  (select count(*)::int from storage.objects
   where bucket_id = 'avatars'
     and name = '00000000-0000-0000-0000-000000000001/alice.jpg'),
  1,
  'a user can read their own photo'
);
select lives_ok(
  $$update storage.objects
    set metadata = '{"mimetype": "image/jpeg", "replaced": true}'
    where bucket_id = 'avatars'
      and name = '00000000-0000-0000-0000-000000000001/alice.jpg'$$,
  'a user can replace their own photo'
);

-- Other folders ---------------------------------------------------------------

select throws_ok(
  $$insert into storage.objects (bucket_id, name, owner_id, metadata)
    values ('avatars', '00000000-0000-0000-0000-000000000002/fake.jpg',
            '00000000-0000-0000-0000-000000000001',
            '{"mimetype": "image/jpeg"}')$$,
  '42501',
  null,
  'a user cannot upload to another folder'
);
select throws_ok(
  $$insert into storage.objects (bucket_id, name, owner_id, metadata)
    values ('avatars', 'alice.jpg', '00000000-0000-0000-0000-000000000001',
            '{"mimetype": "image/jpeg"}')$$,
  '42501',
  null,
  'a user cannot upload outside a folder'
);
select is(
  (select count(*)::int from storage.objects
   where name like '00000000-0000-0000-0000-000000000002/%'),
  0,
  'a user cannot see the photos of others'
);

update storage.objects
set metadata = '{"mimetype": "image/jpeg", "replaced": true}'
where name = '00000000-0000-0000-0000-000000000002/bob.jpg';

-- Profile photo path ----------------------------------------------------------

select lives_ok(
  $$update public.profiles
    set avatar_path = '00000000-0000-0000-0000-000000000001/alice.jpg'
    where id = '00000000-0000-0000-0000-000000000001'$$,
  'a user can use a photo of their own folder'
);
select throws_ok(
  $$update public.profiles
    set avatar_path = '00000000-0000-0000-0000-000000000002/bob.jpg'
    where id = '00000000-0000-0000-0000-000000000001'$$,
  '23514',
  null,
  'a user cannot use the photo of someone else'
);
select throws_ok(
  $$update public.profiles set avatar_path = 'alice.jpg'
    where id = '00000000-0000-0000-0000-000000000001'$$,
  '23514',
  null,
  'a photo path must include the user folder'
);
select throws_ok(
  $$update public.profiles
    set avatar_path = '00000000-0000-0000-0000-000000000001/a/b.jpg'
    where id = '00000000-0000-0000-0000-000000000001'$$,
  '23514',
  null,
  'a photo path cannot point to a subfolder'
);
select throws_ok(
  $$update public.profiles
    set avatar_path = '00000000-0000-0000-0000-000000000001/photo'
    where id = '00000000-0000-0000-0000-000000000001'$$,
  '23514',
  null,
  'a photo path needs an image extension'
);

-- Visitors --------------------------------------------------------------------

reset role;

select is(
  (select metadata ->> 'replaced' from storage.objects
   where name = '00000000-0000-0000-0000-000000000002/bob.jpg'),
  null,
  'updating the photo of another user had no effect'
);

set local role anon;

select is(
  (select count(*)::int from storage.objects where bucket_id = 'avatars'),
  0,
  'visitors who are not signed in see no photo'
);
select throws_ok(
  $$insert into storage.objects (bucket_id, name)
    values ('avatars', '00000000-0000-0000-0000-000000000001/anon.jpg')$$,
  '42501',
  null,
  'visitors who are not signed in cannot upload'
);

select * from finish();

rollback;
