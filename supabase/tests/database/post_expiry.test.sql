begin;

create extension if not exists pgtap with schema extensions;

select plan(14);

-- Fixtures --------------------------------------------------------------------
-- Alice has a live post (live.jpg) and an expired one (old.jpg), pinned by
-- Bob, both uploaded two days ago. She also uploaded recent.jpg two hours ago
-- and stale.jpg 25 hours ago, for posts she never created.

insert into auth.users (id, email, email_confirmed_at) values
  ('00000000-0000-0000-0000-000000000001', 'alice@example.com', now()),
  ('00000000-0000-0000-0000-000000000002', 'bob@example.com', now());

insert into storage.objects (bucket_id, name, owner_id, metadata) values
  ('avatars', '00000000-0000-0000-0000-000000000001/a.jpg',
   '00000000-0000-0000-0000-000000000001', '{"mimetype": "image/jpeg"}');

update public.profiles
set display_name = 'Alice', gender = 'woman', birth_date = '2000-01-01',
  avatar_path = id::text || '/a.jpg'
where id = '00000000-0000-0000-0000-000000000001';

insert into storage.objects (bucket_id, name, owner_id, metadata, created_at)
select 'post-photos', '00000000-0000-0000-0000-000000000001/' || file,
  '00000000-0000-0000-0000-000000000001', '{"mimetype": "image/jpeg"}',
  now() - uploaded_ago
from (values
  ('live.jpg', interval '2 days'),
  ('old.jpg', interval '2 days'),
  ('recent.jpg', interval '2 hours'),
  ('stale.jpg', interval '25 hours')
) as upload(file, uploaded_ago);

insert into public.posts (author_id, image_path, exact_geog, created_at,
  expires_at)
values
  ('00000000-0000-0000-0000-000000000001',
   '00000000-0000-0000-0000-000000000001/live.jpg', 'POINT(6.5668 46.5191)',
   now() - interval '3 hours', now() + interval '1 hour'),
  ('00000000-0000-0000-0000-000000000001',
   '00000000-0000-0000-0000-000000000001/old.jpg', 'POINT(6.5668 46.5191)',
   now() - interval '3 hours', now() - interval '1 minute');

insert into public.pins (user_id, post_id)
select '00000000-0000-0000-0000-000000000002', id from public.posts;

-- Access ----------------------------------------------------------------------

select ok(
  not has_function_privilege(
    'authenticated', 'public.purge_expired_posts(integer)', 'execute'
  ),
  'users cannot purge posts'
);
select ok(
  not has_function_privilege(
    'authenticated', 'public.list_orphan_post_photos(integer)', 'execute'
  ),
  'users cannot list orphan photos'
);
select ok(
  not has_function_privilege('anon', 'public.purge_expired_posts(integer)',
    'execute'),
  'signed-out users cannot purge posts'
);

-- Orphan photos ---------------------------------------------------------------

set local role service_role;

select results_eq(
  'select * from public.list_orphan_post_photos()',
  $$values ('00000000-0000-0000-0000-000000000001/stale.jpg')$$,
  'only photos unused for over a day are orphans'
);

-- Purge -----------------------------------------------------------------------

select results_eq(
  'select * from public.purge_expired_posts()',
  $$values ('00000000-0000-0000-0000-000000000001/old.jpg')$$,
  'the purge returns the photos of the expired posts'
);

reset role;

select is(
  (select array_agg(image_path) from public.posts),
  array['00000000-0000-0000-0000-000000000001/live.jpg'],
  'the purge deletes the expired posts only'
);
select is(
  (select count(*)::int from public.pins),
  1,
  'the pins of a purged post are deleted with it'
);

set local role service_role;

select is_empty(
  'select * from public.purge_expired_posts()',
  'a second purge finds nothing'
);
select results_eq(
  'select * from public.list_orphan_post_photos() order by 1',
  $$values ('00000000-0000-0000-0000-000000000001/old.jpg'),
           ('00000000-0000-0000-0000-000000000001/stale.jpg')$$,
  'a photo the purge could not remove is caught as an orphan'
);

reset role;

-- Schedule --------------------------------------------------------------------

select is(
  (select schedule from cron.job where jobname = 'purge-expired-posts'),
  '*/5 * * * *',
  'the cleanup runs every 5 minutes'
);

select lives_ok(
  'select private.request_post_purge()',
  'without Vault secrets, the job does nothing and does not fail'
);
select is(
  (select count(*)::int from net.http_request_queue),
  0,
  'without Vault secrets, no request is sent'
);

select vault.create_secret('https://example.supabase.co', 'project_url');
select vault.create_secret('sb_secret_test', 'secret_key');

select private.request_post_purge();

select is(
  (select url from net.http_request_queue),
  'https://example.supabase.co/functions/v1/purge-expired-posts',
  'the job calls the Edge Function'
);
select is(
  (select headers ->> 'apikey' from net.http_request_queue),
  'sb_secret_test',
  'the job sends the secret key'
);

select * from finish();

rollback;
