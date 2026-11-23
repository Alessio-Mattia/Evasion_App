begin;

create extension if not exists pgtap with schema extensions;

select plan(67);

-- Fixtures --------------------------------------------------------------------
-- Alice, Bob, Dave and Eve have complete profiles; Carol's is incomplete.
-- Positions are around the EPFL: one degree of latitude is about 111 km.

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

-- A post by the signed-in user at the EPFL, with the photo file, and options.
create function pg_temp.post(file text, options text default '')
returns text
language sql
as $$
  select format(
    'select public.create_post(%L, 46.5191, 6.5668%s)',
    (select auth.uid())::text || '/' || file,
    options
  );
$$;

-- Ids of the posts created below, by name.
create temp table post_ids (name text primary key, id uuid not null);
grant select, insert on post_ids to authenticated;

create function pg_temp.id(post_name text)
returns uuid
language sql
as $$
  select id from post_ids where name = post_name;
$$;

insert into auth.users (id, email, email_confirmed_at) values
  ('00000000-0000-0000-0000-000000000001', 'alice@example.com', now()),
  ('00000000-0000-0000-0000-000000000002', 'bob@example.com', now()),
  ('00000000-0000-0000-0000-000000000003', 'carol@example.com', now()),
  ('00000000-0000-0000-0000-000000000004', 'dave@example.com', now()),
  ('00000000-0000-0000-0000-000000000005', 'eve@example.com', now());

insert into storage.objects (bucket_id, name, owner_id, metadata)
select 'avatars', id::text || '/a.jpg', id, '{"mimetype": "image/jpeg"}'
from auth.users;

update public.profiles
set display_name = 'User', gender = 'other', birth_date = '2000-01-01',
  avatar_path = id::text || '/a.jpg'
where id <> '00000000-0000-0000-0000-000000000003';

-- Photos uploaded to post-photos: a1 to a9 for Alice, b1 and b2 for Bob, and
-- c1, d1, e1 for the others.
insert into storage.objects (bucket_id, name, owner_id, metadata)
select 'post-photos',
  '00000000-0000-0000-0000-000000000001/a' || n || '.jpg',
  '00000000-0000-0000-0000-000000000001',
  '{"mimetype": "image/jpeg"}'
from generate_series(1, 9) as n;

insert into storage.objects (bucket_id, name, owner_id, metadata) values
  ('post-photos', '00000000-0000-0000-0000-000000000002/b1.jpg',
   '00000000-0000-0000-0000-000000000002', '{"mimetype": "image/jpeg"}'),
  ('post-photos', '00000000-0000-0000-0000-000000000002/b2.jpg',
   '00000000-0000-0000-0000-000000000002', '{"mimetype": "image/jpeg"}'),
  ('post-photos', '00000000-0000-0000-0000-000000000003/c1.jpg',
   '00000000-0000-0000-0000-000000000003', '{"mimetype": "image/jpeg"}'),
  ('post-photos', '00000000-0000-0000-0000-000000000004/d1.jpg',
   '00000000-0000-0000-0000-000000000004', '{"mimetype": "image/jpeg"}');

-- Fuzzy area ------------------------------------------------------------------

select ok(
  (select bool_and(
     extensions.st_distance(
       private.fuzzy_point(private.point_from(lat, lng)),
       private.point_from(lat, lng)
     ) < 215
   )
   from (values (46.5191, 6.5668), (46.52, 6.57), (-33.86, 151.21),
                (64.13, -21.9), (0.0001, -0.0001)) as p(lat, lng)),
  'a fuzzy point is within half a cell diagonal of the real point'
);
select ok(
  (select private.fuzzy_point(point) = private.fuzzy_point(
     private.fuzzy_point(point))
   from (select private.point_from(46.5191, 6.5668) as point) as p),
  'the centre of a cell stays the centre of the same cell'
);
select ok(
  (select private.fuzzy_point(private.point_from(46.51910, 6.56680))
     = private.fuzzy_point(private.point_from(46.51911, 6.56681))),
  'two points a metre apart share the same fuzzy point'
);

-- Creating posts --------------------------------------------------------------

select pg_temp.act_as('00000000-0000-0000-0000-000000000001');

insert into post_ids
select 'fuzzy', public.create_post(
  '00000000-0000-0000-0000-000000000001/a1.jpg', 46.5191, 6.5668,
  caption => 'Sunset'
);

select is(
  (select location_precision::text from public.posts_public
   where id = pg_temp.id('fuzzy')),
  'fuzzy',
  'a post is fuzzy by default'
);
select is(
  (select expires_at - created_at from public.posts
   where id = pg_temp.id('fuzzy')),
  interval '24 hours',
  'a post lasts 24 hours by default'
);
select is(
  (select audience::text from public.posts where id = pg_temp.id('fuzzy')),
  'everyone',
  'a post is for everyone by default'
);

insert into post_ids
select 'exact', public.create_post(
  '00000000-0000-0000-0000-000000000001/a2.jpg', 46.5191, 6.5668,
  location_precision => 'exact', lifetime_minutes => 60
);

select results_eq(
  $$select round(latitude::numeric, 6), round(longitude::numeric, 6)
    from public.posts_public where id = pg_temp.id('exact')$$,
  $$values (46.519100::numeric, 6.566800::numeric)$$,
  'an exact post shows its real point'
);
select isnt(
  (select round(latitude::numeric, 6) from public.posts_public
   where id = pg_temp.id('fuzzy')),
  46.519100::numeric,
  'a fuzzy post does not show its real point'
);

select throws_ok(
  'select exact_geog from public.posts',
  '42501', null, 'the exact position cannot be read, even by the author'
);
select throws_ok(
  $$select * from public.posts$$,
  '42501', null, 'selecting every column of posts is refused'
);
select lives_ok(
  $$select * from public.posts_public$$,
  'the public view can be read in full'
);

-- Place
select lives_ok(
  pg_temp.post('a3.jpg', ', 46.5191 + 4900 / 111320.0, 6.5668'),
  'a place 4.9 km away is accepted'
);
select throws_ok(
  pg_temp.post('a4.jpg', ', 46.5191 + 5100 / 111320.0, 6.5668'),
  '23514', 'the place is too far from the device position',
  'a place 5.1 km away is refused'
);
select throws_ok(
  pg_temp.post('a4.jpg', ', place_latitude => 46.52'),
  '23514', null, 'a place needs both coordinates'
);
select throws_ok(
  $$select public.create_post(
      '00000000-0000-0000-0000-000000000001/a4.jpg', null, null)$$,
  '23514', null, 'the device position is required'
);
select throws_ok(
  $$select public.create_post(
      '00000000-0000-0000-0000-000000000001/a4.jpg', 91, 6.5668)$$,
  '23514', null, 'coordinates out of range are refused'
);

-- Lifetime, caption, photo, audience
select throws_ok(
  pg_temp.post('a4.jpg', ', lifetime_minutes => 59'),
  '23514', null, 'a lifetime under 1 hour is refused'
);
select throws_ok(
  pg_temp.post('a4.jpg', ', lifetime_minutes => 43201'),
  '23514', null, 'a lifetime over 30 days is refused'
);
select throws_ok(
  pg_temp.post('a4.jpg', ', caption => ''  '''),
  '23514', null, 'a blank caption is refused'
);
select throws_ok(
  pg_temp.post('a4.jpg', format(', caption => %L', repeat('a', 301))),
  '23514', null, 'a caption over 300 characters is refused'
);
select throws_ok(
  pg_temp.post('never-uploaded.jpg'),
  '23514', 'image_path must point to an uploaded photo',
  'the photo must be uploaded'
);
select throws_ok(
  $$select public.create_post(
      '00000000-0000-0000-0000-000000000002/b1.jpg', 46.5191, 6.5668)$$,
  '23514', null, 'a post cannot use the photo of someone else'
);
select throws_ok(
  pg_temp.post('a1.jpg'),
  '23505', null, 'two posts cannot share a photo'
);
select throws_ok(
  pg_temp.post('a4.jpg', ', audience => ''selected'''),
  '23514', null, 'a selected audience needs a list'
);
select throws_ok(
  pg_temp.post('a4.jpg', $$, audience => 'selected',
    audience_ids => array['00000000-0000-0000-0000-000000000002']::uuid[]$$),
  '23514', 'a selected audience can only list friends',
  'a selected audience can only list friends'
);
select throws_ok(
  pg_temp.post('a4.jpg', $$, audience => 'friends',
    audience_ids => array['00000000-0000-0000-0000-000000000002']::uuid[]$$),
  '23514', null, 'only a selected audience takes a list'
);

insert into post_ids
select 'friends', public.create_post(
  '00000000-0000-0000-0000-000000000001/a4.jpg', 46.5191, 6.5668,
  audience => 'friends'
);

-- Alice now has 4 active posts: fuzzy, exact, the 4.9 km one, friends.
insert into post_ids
select 'fifth', public.create_post(
  '00000000-0000-0000-0000-000000000001/a5.jpg', 46.5191, 6.5668
);

select throws_ok(
  pg_temp.post('a6.jpg'),
  '54000', 'too many active posts',
  'a sixth active post is refused'
);

select throws_ok(
  $$insert into public.posts (image_path, exact_geog, expires_at)
    values ('00000000-0000-0000-0000-000000000001/a6.jpg',
            'POINT(6.5668 46.5191)', now() + interval '1 day')$$,
  '42501', null, 'posts cannot be inserted directly'
);
select throws_ok(
  $$update public.posts set caption = 'Changed'$$,
  '42501', null, 'posts cannot be updated directly'
);

select pg_temp.act_as('00000000-0000-0000-0000-000000000003');

select throws_ok(
  pg_temp.post('c1.jpg'),
  '42501', 'the profile must be complete to post',
  'an incomplete profile cannot post'
);

reset role;

select ok(
  not has_function_privilege(
    'anon',
    'public.create_post(text, double precision, double precision,
      double precision, double precision, public.post_precision, integer,
      public.post_audience, uuid[], text)',
    'execute'
  ),
  'signed-out users cannot create posts'
);

-- Visibility ------------------------------------------------------------------

select pg_temp.act_as('00000000-0000-0000-0000-000000000004');

insert into post_ids
select 'dave', public.create_post(
  '00000000-0000-0000-0000-000000000004/d1.jpg', 46.5191, 6.5668
);

reset role;

insert into public.blocks (blocker_id, blocked_id)
values ('00000000-0000-0000-0000-000000000001',
        '00000000-0000-0000-0000-000000000004');

select pg_temp.act_as('00000000-0000-0000-0000-000000000002');

select is(
  (select count(*)::int from public.posts_public
   where id in (pg_temp.id('fuzzy'), pg_temp.id('exact'))),
  2,
  'another user sees the posts for everyone'
);
select is(
  (select count(*)::int from public.posts_public
   where id = pg_temp.id('friends')),
  0,
  'a post for friends is hidden from non-friends'
);

select pg_temp.act_as('00000000-0000-0000-0000-000000000003');

select is(
  (select count(*)::int from public.posts_public),
  0,
  'a user with an incomplete profile sees no post'
);

select pg_temp.act_as('00000000-0000-0000-0000-000000000004');

select is(
  (select count(*)::int from public.posts_public
   where author_id = '00000000-0000-0000-0000-000000000001'),
  0,
  'a blocked user does not see the posts of who blocked them'
);

select pg_temp.act_as('00000000-0000-0000-0000-000000000001');

select is(
  (select count(*)::int from public.posts_public
   where id = pg_temp.id('dave')),
  0,
  'a user does not see the posts of someone they blocked'
);
select is(
  (select count(*)::int from public.posts_public
   where author_id = '00000000-0000-0000-0000-000000000001'),
  5,
  'the author sees all their posts, whatever the audience'
);

reset role;

-- The fifth post expired an hour ago.
update public.posts
set created_at = now() - interval '2 hours',
  expires_at = now() - interval '1 hour'
where id = pg_temp.id('fifth');

select pg_temp.act_as('00000000-0000-0000-0000-000000000001');

select is(
  (select count(*)::int from public.posts_public
   where id = pg_temp.id('fifth')),
  0,
  'an expired post disappears, for its author too'
);
select lives_ok(
  pg_temp.post('a6.jpg'),
  'an expired post no longer counts in the quota'
);

-- Friends ---------------------------------------------------------------------
-- Friendships do not exist yet: replace the function for this test only.
-- Alice is friends with Bob and Eve.

reset role;

create or replace function private.are_friends(a uuid, b uuid)
returns boolean
language sql
stable
set search_path = ''
as $$
  select array[a, b] <@ array[
      '00000000-0000-0000-0000-000000000001',
      '00000000-0000-0000-0000-000000000002',
      '00000000-0000-0000-0000-000000000005'
    ]::uuid[]
    and '00000000-0000-0000-0000-000000000001' in (a, b)
    and a <> b;
$$;

select pg_temp.act_as('00000000-0000-0000-0000-000000000002');

select is(
  (select count(*)::int from public.posts_public
   where id = pg_temp.id('friends')),
  1,
  'a friend sees a post for friends'
);

select pg_temp.act_as('00000000-0000-0000-0000-000000000001');

-- Alice is at her quota of 5: delete the 4.9 km post to make room.
delete from public.posts
where image_path = '00000000-0000-0000-0000-000000000001/a3.jpg';

insert into post_ids
select 'selected', public.create_post(
  '00000000-0000-0000-0000-000000000001/a7.jpg', 46.5191, 6.5668,
  audience => 'selected',
  audience_ids => array[
    '00000000-0000-0000-0000-000000000002',
    '00000000-0000-0000-0000-000000000002'
  ]::uuid[]
);

select is(
  (select count(*)::int from public.post_audience_members
   where post_id = pg_temp.id('selected')),
  1,
  'a friend listed twice is in the audience once'
);

select pg_temp.act_as('00000000-0000-0000-0000-000000000002');

select is(
  (select count(*)::int from public.posts_public
   where id = pg_temp.id('selected')),
  1,
  'a listed friend sees the post'
);
select is(
  (select count(*)::int from public.post_audience_members),
  0,
  'only the author sees the audience list'
);

select pg_temp.act_as('00000000-0000-0000-0000-000000000005');

select is(
  (select count(*)::int from public.posts_public
   where id = pg_temp.id('selected')),
  0,
  'a friend who is not listed does not see the post'
);

-- Changing posts --------------------------------------------------------------

select pg_temp.act_as('00000000-0000-0000-0000-000000000001');

select lives_ok(
  format(
    $$select public.update_post(%L, audience_ids => array[
        '00000000-0000-0000-0000-000000000005']::uuid[])$$,
    pg_temp.id('selected')
  ),
  'the author can change the list of a selected audience'
);

select pg_temp.act_as('00000000-0000-0000-0000-000000000002');

select is(
  (select count(*)::int from public.posts_public
   where id = pg_temp.id('selected')),
  0,
  'a friend removed from the list no longer sees the post'
);

select pg_temp.act_as('00000000-0000-0000-0000-000000000005');

select is(
  (select count(*)::int from public.posts_public
   where id = pg_temp.id('selected')),
  1,
  'a friend added to the list sees the post'
);

select pg_temp.act_as('00000000-0000-0000-0000-000000000001');

select lives_ok(
  format(
    $$select public.update_post(%L, audience => 'everyone')$$,
    pg_temp.id('selected')
  ),
  'the author can open a post to everyone'
);
select is(
  (select count(*)::int from public.post_audience_members
   where post_id = pg_temp.id('selected')),
  0,
  'the list is cleared when the audience is no longer selected'
);
select throws_ok(
  format(
    $$select public.update_post(%L, audience => 'selected')$$,
    pg_temp.id('selected')
  ),
  '23514', null, 'switching to a selected audience needs a list'
);

select lives_ok(
  format(
    $$select public.update_post(%L, lifetime_minutes => 43200)$$,
    pg_temp.id('fuzzy')
  ),
  'the author can extend a post up to 30 days'
);
select is(
  (select expires_at - created_at from public.posts
   where id = pg_temp.id('fuzzy')),
  interval '30 days',
  'the new lifetime is counted from the creation'
);
select throws_ok(
  format(
    $$select public.update_post(%L, lifetime_minutes => 43201)$$,
    pg_temp.id('fuzzy')
  ),
  '23514', null, 'a lifetime over 30 days is refused on change too'
);

reset role;

-- The exact post was created 3 hours ago and still runs for an hour.
update public.posts
set created_at = now() - interval '3 hours',
  expires_at = now() + interval '1 hour'
where id = pg_temp.id('exact');

select pg_temp.act_as('00000000-0000-0000-0000-000000000001');

select throws_ok(
  format(
    $$select public.update_post(%L, lifetime_minutes => 60)$$,
    pg_temp.id('exact')
  ),
  '23514', 'the new lifetime must end in the future',
  'a lifetime that would already be over is refused'
);

select pg_temp.act_as('00000000-0000-0000-0000-000000000002');

select throws_ok(
  format(
    $$select public.update_post(%L, lifetime_minutes => 120)$$,
    pg_temp.id('fuzzy')
  ),
  'P0002', 'post not found', 'only the author can change a post'
);

-- Pins ------------------------------------------------------------------------

select lives_ok(
  format(
    'insert into public.pins (post_id) values (%L)',
    pg_temp.id('fuzzy')
  ),
  'a user can pin a post they see'
);
select throws_ok(
  format(
    'insert into public.pins (post_id) values (%L)',
    pg_temp.id('fifth')
  ),
  '42501', null, 'a user cannot pin a post they cannot see'
);
select throws_ok(
  format(
    $$insert into public.pins (user_id, post_id)
      values ('00000000-0000-0000-0000-000000000005', %L)$$,
    pg_temp.id('exact')
  ),
  '42501', null, 'a user cannot pin for someone else'
);

select pg_temp.act_as('00000000-0000-0000-0000-000000000001');

select is(
  (select count(*)::int from public.pins),
  0,
  'the author does not see who pinned their post'
);

-- Photo files -----------------------------------------------------------------

select pg_temp.act_as('00000000-0000-0000-0000-000000000002');

select is(
  (select count(*)::int from storage.objects
   where name = '00000000-0000-0000-0000-000000000001/a1.jpg'),
  1,
  'a user can read the photo of a post they see'
);
select is(
  (select count(*)::int from storage.objects
   where name = '00000000-0000-0000-0000-000000000001/a5.jpg'),
  0,
  'a user cannot read the photo of an expired post'
);
select is(
  (select count(*)::int from storage.objects
   where name = '00000000-0000-0000-0000-000000000001/a3.jpg'),
  0,
  'a user cannot read a photo no post uses'
);

select pg_temp.act_as('00000000-0000-0000-0000-000000000001');

-- Supabase blocks deletions in SQL unless this setting is on, as the Storage
-- API does: the policies are then checked as for a real deletion.
select set_config('storage.allow_delete_query', 'true', true);

delete from storage.objects
where name = '00000000-0000-0000-0000-000000000001/a1.jpg';

select is(
  (select count(*)::int from storage.objects
   where name = '00000000-0000-0000-0000-000000000001/a1.jpg'),
  1,
  'the photo of a live post cannot be deleted'
);

-- Deleting posts --------------------------------------------------------------

select pg_temp.act_as('00000000-0000-0000-0000-000000000002');

delete from public.posts where id = pg_temp.id('fuzzy');

select pg_temp.act_as('00000000-0000-0000-0000-000000000001');

select is(
  (select count(*)::int from public.posts where id = pg_temp.id('fuzzy')),
  1,
  'a user cannot delete the post of someone else'
);

delete from public.posts where id = pg_temp.id('fuzzy');

select is(
  (select count(*)::int from public.posts where id = pg_temp.id('fuzzy')),
  0,
  'the author can delete their post'
);

delete from storage.objects
where name = '00000000-0000-0000-0000-000000000001/a1.jpg';

select is(
  (select count(*)::int from storage.objects
   where name = '00000000-0000-0000-0000-000000000001/a1.jpg'),
  0,
  'the photo of a deleted post can be deleted'
);

reset role;

select is(
  (select count(*)::int from public.pins where post_id = pg_temp.id('fuzzy')),
  0,
  'the pins of a deleted post are deleted too'
);

select * from finish();

rollback;
