-- The posts shown on the map: those of the visible area.
--
-- map_feed runs with the rights of the caller (security invoker): the
-- policies of posts decide what they see (audience, blocks, complete
-- profiles, expiry), exactly as for posts_public. It adds what the map
-- needs: the area, the author's name and photo, and the caller's pins.
--
-- Two limits keep anyone from downloading every post at once. Both mirror
-- BusinessRules (business_rules.dart) and are provisional until the release:
-- an area of at most 50 km on each side (mapFeedMaxAreaSideMeters), and the
-- 200 most recent posts (mapFeedMaxPosts).

-- map_feed runs as the caller, who needs this helper. It only builds a point
-- from coordinates.
grant execute on function
  private.point_from(double precision, double precision) to authenticated;

create function public.map_feed(
  min_latitude double precision,
  min_longitude double precision,
  max_latitude double precision,
  max_longitude double precision
)
returns table (
  id uuid,
  author_id uuid,
  author_name text,
  author_avatar_path text,
  image_path text,
  caption text,
  latitude double precision,
  longitude double precision,
  location_precision public.post_precision,
  created_at timestamptz,
  expires_at timestamptz,
  is_pinned boolean
)
language plpgsql
stable
set search_path = ''
as $$
#variable_conflict use_column
declare
  south_west extensions.geography;
  north_east extensions.geography;
  area extensions.geography;
begin
  -- point_from refuses coordinates outside the globe and returns null when
  -- one is missing.
  south_west := private.point_from(min_latitude, min_longitude);
  north_east := private.point_from(max_latitude, max_longitude);
  if south_west is null or north_east is null
    or min_latitude >= max_latitude or min_longitude >= max_longitude
  then
    raise exception 'the area needs a south-west and a north-east corner'
      using errcode = 'check_violation';
  end if;

  -- Height, and width along the edge closer to the equator, the wider one.
  if extensions.st_distance(
       south_west, private.point_from(max_latitude, min_longitude)
     ) > 50000
     or extensions.st_distance(
       private.point_from(
         case when abs(min_latitude) < abs(max_latitude)
           then min_latitude else max_latitude end,
         min_longitude
       ),
       private.point_from(
         case when abs(min_latitude) < abs(max_latitude)
           then min_latitude else max_latitude end,
         max_longitude
       )
     ) > 50000
     -- Over 180 degrees, st_distance would measure the short way round.
     or max_longitude - min_longitude > 180
  then
    raise exception 'the area is larger than 50 km on a side'
      using errcode = 'check_violation';
  end if;

  area := extensions.st_makeenvelope(
    min_longitude, min_latitude, max_longitude, max_latitude, 4326
  )::extensions.geography;

  return query
  select
    post.id,
    post.author_id,
    author.display_name,
    author.avatar_path,
    post.image_path,
    post.caption,
    extensions.st_y(post.display_geog::extensions.geometry),
    extensions.st_x(post.display_geog::extensions.geometry),
    post.location_precision,
    post.created_at,
    post.expires_at,
    exists (
      select 1 from public.pins as pin
      where pin.post_id = post.id and pin.user_id = (select auth.uid())
    )
  from public.posts as post
  cross join lateral public.get_public_profile(post.author_id) as author
  where extensions.st_intersects(post.display_geog, area)
  order by post.created_at desc
  limit 200;
end;
$$;

revoke all on function public.map_feed(
  double precision, double precision, double precision, double precision
) from public, anon;
grant execute on function public.map_feed(
  double precision, double precision, double precision, double precision
) to authenticated;
