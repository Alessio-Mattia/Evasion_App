begin;

create extension if not exists pgtap with schema extensions;

select plan(37);

-- Fixtures --------------------------------------------------------------------
-- Alice and Bob have complete profiles; Carol's is incomplete.

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

create function pg_temp.page(content jsonb, page_type text, page_position int)
returns text
language sql
as $$
  select format(
    'insert into public.profile_pages (position, type, content) values (%s, %L, %L)',
    page_position, page_type, content
  );
$$;

insert into auth.users (id, email, email_confirmed_at) values
  ('00000000-0000-0000-0000-000000000001', 'alice@example.com', now()),
  ('00000000-0000-0000-0000-000000000002', 'bob@example.com', now()),
  ('00000000-0000-0000-0000-000000000003', 'carol@example.com', now());

insert into storage.objects (bucket_id, name, owner_id, metadata) values
  ('avatars', '00000000-0000-0000-0000-000000000001/a.jpg',
   '00000000-0000-0000-0000-000000000001', '{"mimetype": "image/jpeg"}'),
  ('avatars', '00000000-0000-0000-0000-000000000002/b.jpg',
   '00000000-0000-0000-0000-000000000002', '{"mimetype": "image/jpeg"}'),
  ('profile-photos', '00000000-0000-0000-0000-000000000001/beach.jpg',
   '00000000-0000-0000-0000-000000000001', '{"mimetype": "image/jpeg"}'),
  ('profile-photos', '00000000-0000-0000-0000-000000000001/unused.jpg',
   '00000000-0000-0000-0000-000000000001', '{"mimetype": "image/jpeg"}'),
  ('profile-photos', '00000000-0000-0000-0000-000000000002/bob.jpg',
   '00000000-0000-0000-0000-000000000002', '{"mimetype": "image/jpeg"}');

update public.profiles
set display_name = 'Alice', gender = 'woman', birth_date = '2000-01-01',
  avatar_path = id::text || '/a.jpg'
where id = '00000000-0000-0000-0000-000000000001';

update public.profiles
set display_name = 'Bob', gender = 'man', birth_date = '2000-01-01',
  avatar_path = id::text || '/b.jpg'
where id = '00000000-0000-0000-0000-000000000002';

-- Templates -------------------------------------------------------------------

select pg_temp.act_as('00000000-0000-0000-0000-000000000001');

select lives_ok(
  pg_temp.page('{"text": "Hello"}', 'text', 1),
  'a text page is accepted'
);
select throws_ok(
  pg_temp.page('{"text": "  "}', 'text', 2),
  '23514', null, 'an empty text is refused'
);
select throws_ok(
  pg_temp.page(jsonb_build_object('text', repeat('a', 301)), 'text', 2),
  '23514', null, 'a text over 300 characters is refused'
);
select throws_ok(
  pg_temp.page('{"text": "Hi", "color": "red"}', 'text', 2),
  '23514', null, 'an unknown key is refused'
);
select lives_ok(
  pg_temp.page('{"interests": ["sport", "music"]}', 'interests', 2),
  'an interests page is accepted'
);
select throws_ok(
  pg_temp.page('{"interests": ["sport", "skydiving"]}', 'interests', 3),
  '23514', null, 'an interest outside the list is refused'
);
select throws_ok(
  pg_temp.page('{"interests": ["sport", "sport"]}', 'interests', 3),
  '23514', null, 'a repeated interest is refused'
);
select throws_ok(
  pg_temp.page('{"interests": []}', 'interests', 3),
  '23514', null, 'an empty interests page is refused'
);
select throws_ok(
  pg_temp.page(
    '{"interests": ["sport", "music", "movies", "reading", "travel", "cooking",
      "gaming", "art", "nature", "nightlife", "technology"]}',
    'interests', 3
  ),
  '23514', null, 'more than 10 interests are refused'
);
select throws_ok(
  $$insert into public.profile_pages (position, type, content, image_path)
    values (3, 'photo', '{}',
            '00000000-0000-0000-0000-000000000001/never-uploaded.jpg')$$,
  '23514',
  'image_path must point to an uploaded photo',
  'a photo page needs an uploaded file'
);
select throws_ok(
  $$insert into public.profile_pages (position, type, content, image_path)
    values (3, 'photo', '{}', '00000000-0000-0000-0000-000000000002/bob.jpg')$$,
  '23514', null, 'a photo page cannot use the photo of someone else'
);
select throws_ok(
  format(
    $$insert into public.profile_pages (position, type, content, image_path)
      values (3, 'photo', %L,
              '00000000-0000-0000-0000-000000000001/beach.jpg')$$,
    jsonb_build_object('caption', repeat('a', 101))
  ),
  '23514', null, 'a caption over 100 characters is refused'
);
select lives_ok(
  $$insert into public.profile_pages (position, type, content, image_path)
    values (3, 'photo', '{"caption": "Summer"}',
            '00000000-0000-0000-0000-000000000001/beach.jpg')$$,
  'a photo page with a caption is accepted'
);
select throws_ok(
  pg_temp.page('{"text": "Hi"}', 'photo', 4),
  '23514', null, 'a photo page needs a photo'
);

-- Positions -------------------------------------------------------------------

select throws_ok(
  pg_temp.page('{"text": "Hi"}', 'text', 6),
  '23514', null, 'there are at most 5 free pages'
);
select throws_ok(
  pg_temp.page('{"text": "Hi"}', 'text', 1),
  '23505', null, 'two pages cannot share a position'
);

select lives_ok(pg_temp.page('{"text": "Four"}', 'text', 4), 'page 4');
select lives_ok(pg_temp.page('{"text": "Five"}', 'text', 5), 'page 5');

select throws_ok(
  $$insert into public.profile_pages (profile_id, position, type, content)
    values ('00000000-0000-0000-0000-000000000002', 1, 'text',
            '{"text": "Hi"}')$$,
  '42501', null, 'a user cannot add a page to another profile'
);

-- Reordering ------------------------------------------------------------------

select lives_ok(
  $$select public.reorder_profile_pages(array(
      select id from public.profile_pages order by position desc
    ))$$,
  'a user can reorder their pages'
);
select is(
  (select content ->> 'text' from public.profile_pages where position = 1),
  'Five',
  'the last page is now first'
);
select is(
  (select content ->> 'text' from public.profile_pages where position = 5),
  'Hello',
  'the first page is now last'
);
select throws_ok(
  $$select public.reorder_profile_pages(array(
      select id from public.profile_pages where position <= 2
    ))$$,
  '22023', null, 'reordering must list every page'
);

-- Photo files -----------------------------------------------------------------

-- Supabase blocks deletions in SQL unless this setting is on, as the Storage
-- API does: the policies are then checked as for a real deletion.
select set_config('storage.allow_delete_query', 'true', true);

delete from storage.objects
where name = '00000000-0000-0000-0000-000000000001/beach.jpg';

select is(
  (select count(*)::int from storage.objects
   where name = '00000000-0000-0000-0000-000000000001/beach.jpg'),
  1,
  'a photo used by a page cannot be deleted'
);

-- Other users -----------------------------------------------------------------

select pg_temp.act_as('00000000-0000-0000-0000-000000000002');

select is(
  (select count(*)::int from public.profile_pages
   where profile_id = '00000000-0000-0000-0000-000000000001'),
  5,
  'a user sees the pages of a visible profile'
);
select is(
  (select count(*)::int from storage.objects
   where name = '00000000-0000-0000-0000-000000000001/beach.jpg'),
  1,
  'and the photos of these pages'
);
select is(
  (select count(*)::int from storage.objects
   where name = '00000000-0000-0000-0000-000000000001/unused.jpg'),
  0,
  'but not the photos no page uses'
);
select throws_ok(
  $$select public.reorder_profile_pages(array(
      select id from public.profile_pages
      where profile_id = '00000000-0000-0000-0000-000000000001'
    ))$$,
  '22023', null, 'a user cannot reorder the pages of someone else'
);

update public.profile_pages set content = '{"text": "Hacked"}'
where profile_id = '00000000-0000-0000-0000-000000000001';
delete from public.profile_pages
where profile_id = '00000000-0000-0000-0000-000000000001';

reset role;

select is(
  (select count(*)::int from public.profile_pages
   where profile_id = '00000000-0000-0000-0000-000000000001'
     and content ->> 'text' = 'Hacked'),
  0,
  'a user cannot change the pages of someone else'
);
select is(
  (select count(*)::int from public.profile_pages
   where profile_id = '00000000-0000-0000-0000-000000000001'),
  5,
  'a user cannot delete the pages of someone else'
);

insert into public.blocks (blocker_id, blocked_id) values
  ('00000000-0000-0000-0000-000000000001',
   '00000000-0000-0000-0000-000000000002');

select pg_temp.act_as('00000000-0000-0000-0000-000000000002');

select is(
  (select count(*)::int from public.profile_pages
   where profile_id = '00000000-0000-0000-0000-000000000001'),
  0,
  'the pages of a blocked profile are hidden'
);
select is(
  (select count(*)::int from storage.objects
   where name = '00000000-0000-0000-0000-000000000001/beach.jpg'),
  0,
  'and so are their photos'
);

select pg_temp.act_as('00000000-0000-0000-0000-000000000003');

select is(
  (select count(*)::int from public.profile_pages),
  0,
  'a user with an incomplete profile sees no page'
);

reset role;
set local role anon;

select throws_ok(
  $$select * from public.profile_pages$$,
  '42501', null, 'visitors who are not signed in see no page'
);

reset role;

-- Bucket and account deletion -------------------------------------------------

select is(
  (select public from storage.buckets where id = 'profile-photos'),
  false,
  'the profile-photos bucket is private'
);
select is(
  (select file_size_limit from storage.buckets where id = 'profile-photos'),
  5242880::bigint,
  'page photos are limited to 5 MB'
);

delete from auth.users where id = '00000000-0000-0000-0000-000000000001';

select is(
  (select count(*)::int from public.profile_pages),
  0,
  'deleting the account deletes the pages'
);

select * from finish();

rollback;
