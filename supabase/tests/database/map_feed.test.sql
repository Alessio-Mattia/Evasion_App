begin;

create extension if not exists pgtap with schema extensions;

select plan(18);

-- Fixtures --------------------------------------------------------------------
-- Alice, Bob and Dave have complete profiles; Carol's is incomplete. Alice
-- blocked Dave. Posts are inserted directly, as create_post is tested in
-- posts.test.sql. The EPFL is at 46.519, 6.567; Geneva is about 50 km away.

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

-- The posts the signed-in user sees around the EPFL, in a box of about
-- 2 km by 2 km.
create temp view epfl_feed with (security_invoker = true) as
select * from public.map_feed(46.51, 6.555, 46.53, 6.58);

grant select on epfl_feed to authenticated;

insert into auth.users (id, email, email_confirmed_at) values
  ('00000000-0000-0000-0000-000000000001', 'alice@example.com', now()),
  ('00000000-0000-0000-0000-000000000002', 'bob@example.com', now()),
  ('00000000-0000-0000-0000-000000000003', 'carol@example.com', now()),
  ('00000000-0000-0000-0000-000000000004', 'dave@example.com', now());

insert into storage.objects (bucket_id, name, owner_id, metadata)
select 'avatars', id::text || '/a.jpg', id, '{"mimetype": "image/jpeg"}'
from auth.users;

update public.profiles
set display_name = initcap(split_part(
    (select email from auth.users where users.id = profiles.id), '@', 1)),
  gender = 'other', birth_date = '2000-01-01',
  avatar_path = id::text || '/a.jpg'
where id <> '00000000-0000-0000-0000-000000000003';

insert into public.blocks (blocker_id, blocked_id)
values ('00000000-0000-0000-0000-000000000001',
        '00000000-0000-0000-0000-000000000004');

insert into public.posts (author_id, image_path, exact_geog,
  location_precision, audience, created_at, expires_at)
values
  -- Alice, at the EPFL, exact, the most recent.
  ('00000000-0000-0000-0000-000000000001',
   '00000000-0000-0000-0000-000000000001/epfl.jpg', 'POINT(6.5668 46.5191)',
   'exact', 'everyone', now() - interval '1 minute', now() + interval '1 day'),
  -- Alice, in Geneva, outside the box.
  ('00000000-0000-0000-0000-000000000001',
   '00000000-0000-0000-0000-000000000001/geneva.jpg', 'POINT(6.1432 46.2044)',
   'fuzzy', 'everyone', now() - interval '2 minutes', now() + interval '1 day'),
  -- Alice, at the EPFL, for her friends only.
  ('00000000-0000-0000-0000-000000000001',
   '00000000-0000-0000-0000-000000000001/friends.jpg', 'POINT(6.5668 46.5191)',
   'fuzzy', 'friends', now() - interval '3 minutes', now() + interval '1 day'),
  -- Alice, at the EPFL, expired.
  ('00000000-0000-0000-0000-000000000001',
   '00000000-0000-0000-0000-000000000001/expired.jpg', 'POINT(6.5668 46.5191)',
   'fuzzy', 'everyone', now() - interval '2 hours', now() - interval '1 hour'),
  -- Bob, at the EPFL, fuzzy.
  ('00000000-0000-0000-0000-000000000002',
   '00000000-0000-0000-0000-000000000002/bob.jpg', 'POINT(6.5668 46.5191)',
   'fuzzy', 'everyone', now() - interval '4 minutes', now() + interval '1 day'),
  -- Dave, at the EPFL.
  ('00000000-0000-0000-0000-000000000004',
   '00000000-0000-0000-0000-000000000004/dave.jpg', 'POINT(6.5668 46.5191)',
   'fuzzy', 'everyone', now() - interval '5 minutes', now() + interval '1 day');

insert into public.pins (user_id, post_id)
select '00000000-0000-0000-0000-000000000002', id from public.posts
where image_path like '%/epfl.jpg';

-- What Bob sees ---------------------------------------------------------------

select pg_temp.act_as('00000000-0000-0000-0000-000000000002');

select results_eq(
  'select image_path from epfl_feed',
  $$values ('00000000-0000-0000-0000-000000000001/epfl.jpg'),
           ('00000000-0000-0000-0000-000000000002/bob.jpg'),
           ('00000000-0000-0000-0000-000000000004/dave.jpg')$$,
  'the feed lists the visible posts of the area, the most recent first'
);
select is(
  (select author_name from epfl_feed
   where image_path like '%/epfl.jpg'),
  'Alice',
  'the feed gives the name of the author'
);
select is(
  (select author_avatar_path from epfl_feed
   where image_path like '%/epfl.jpg'),
  '00000000-0000-0000-0000-000000000001/a.jpg',
  'the feed gives the photo of the author'
);
select results_eq(
  $$select round(latitude::numeric, 6), round(longitude::numeric, 6)
    from epfl_feed where image_path like '%/epfl.jpg'$$,
  $$values (46.519100::numeric, 6.566800::numeric)$$,
  'an exact post is at its point'
);
select isnt(
  (select round(latitude::numeric, 6) from epfl_feed
   where image_path like '%/bob.jpg'),
  46.519100::numeric,
  'a fuzzy post is at the centre of its cell'
);
select results_eq(
  $$select image_path, is_pinned from epfl_feed
    where image_path like '%/epfl.jpg' or image_path like '%/bob.jpg'$$,
  $$values ('00000000-0000-0000-0000-000000000001/epfl.jpg', true),
           ('00000000-0000-0000-0000-000000000002/bob.jpg', false)$$,
  'the feed says which posts the user pinned'
);
select is_empty(
  'select * from public.map_feed(46.1, 6.0, 46.3, 6.3)
   where image_path like ''%/epfl.jpg''',
  'a post outside the area is left out'
);

-- Other users -----------------------------------------------------------------

select pg_temp.act_as('00000000-0000-0000-0000-000000000004');

select is_empty(
  $$select * from epfl_feed
    where author_id = '00000000-0000-0000-0000-000000000001'$$,
  'a blocked user does not see the posts of who blocked them'
);

select pg_temp.act_as('00000000-0000-0000-0000-000000000001');

select is(
  (select count(*)::int from epfl_feed
   where author_id = '00000000-0000-0000-0000-000000000001'),
  2,
  'the author sees their live posts, including those for friends'
);
select is_empty(
  $$select * from epfl_feed
    where author_id = '00000000-0000-0000-0000-000000000004'$$,
  'a user does not see the posts of someone they blocked'
);

select pg_temp.act_as('00000000-0000-0000-0000-000000000003');

select is_empty(
  'select * from epfl_feed',
  'a user with an incomplete profile sees no post'
);

-- Area ------------------------------------------------------------------------

select pg_temp.act_as('00000000-0000-0000-0000-000000000002');

select lives_ok(
  -- 0.44 degree of latitude is about 49 km; 0.6 of longitude, 46 km here.
  'select * from public.map_feed(46.3, 6.3, 46.74, 6.9)',
  'an area of under 50 km on each side is accepted'
);
select throws_ok(
  'select * from public.map_feed(46.3, 6.3, 46.76, 6.6)',
  '23514', 'the area is larger than 50 km on a side',
  'an area over 50 km high is refused'
);
select throws_ok(
  'select * from public.map_feed(46.5, 6.0, 46.6, 6.7)',
  '23514', 'the area is larger than 50 km on a side',
  'an area over 50 km wide is refused'
);
select throws_ok(
  'select * from public.map_feed(46.53, 6.555, 46.51, 6.58)',
  '23514', null, 'the corners must be in order'
);
select throws_ok(
  'select * from public.map_feed(null, 6.555, 46.53, 6.58)',
  '23514', null, 'every corner is required'
);

reset role;

select ok(
  not has_function_privilege(
    'anon',
    'public.map_feed(double precision, double precision, double precision,
      double precision)',
    'execute'
  ),
  'signed-out users cannot read the map'
);

-- Limit -----------------------------------------------------------------------

-- 200 more posts from Bob at the EPFL, all older than the others.
insert into public.posts (author_id, image_path, exact_geog, created_at,
  expires_at)
select '00000000-0000-0000-0000-000000000002',
  '00000000-0000-0000-0000-000000000002/many' || n || '.jpg',
  'POINT(6.5668 46.5191)', now() - interval '1 hour' - n * interval '1 second',
  now() + interval '1 day'
from generate_series(1, 200) as n;

select pg_temp.act_as('00000000-0000-0000-0000-000000000002');

select results_eq(
  $$select count(*)::int, count(*) filter (
      where image_path like '%/epfl.jpg')::int
    from epfl_feed$$,
  $$values (200, 1)$$,
  'the feed keeps the 200 most recent posts'
);

select * from finish();

rollback;
