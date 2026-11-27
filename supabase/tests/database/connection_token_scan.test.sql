begin;

create extension if not exists pgtap with schema extensions;

select plan(8);

-- Fixtures --------------------------------------------------------------------
-- Alice shows her QR code; Bob scans it; Eve is someone else.

create temp table people (name text primary key, id uuid not null);
create temp table kept (name text primary key, value text);
grant select on people to authenticated;
grant select, insert on kept to authenticated;

create function pg_temp.user_id(person text)
returns uuid
language sql
as $$
  select id from people where name = person;
$$;

create function pg_temp.act_as(person text)
returns void
language plpgsql
as $$
begin
  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', pg_temp.user_id(person), 'role',
      'authenticated')::text,
    true
  );
  set local role authenticated;
end;
$$;

-- Who person sees as the scanner of Alice's token.
create function pg_temp.scanner_seen_by(person text)
returns text
language plpgsql
as $$
declare
  seen text;
begin
  perform pg_temp.act_as(person);
  select display_name into seen
  from public.connection_token_scan(
    (select value from kept where name = 'alice token')
  );
  reset role;
  return seen;
end;
$$;

insert into people (name, id)
select name, gen_random_uuid()
from unnest(array['alice', 'bob', 'eve']) as name;

insert into auth.users (id, email, email_confirmed_at)
select id, name || '@example.com', now() from people;

insert into storage.objects (bucket_id, name, owner_id, metadata)
select 'avatars', id::text || '/a.jpg', id, '{"mimetype": "image/jpeg"}'
from people;

update public.profiles as profile
set display_name = initcap(people.name), gender = 'other',
  birth_date = '2000-01-01', avatar_path = profile.id::text || '/a.jpg'
from people
where people.id = profile.id;

select pg_temp.act_as('alice');
insert into kept
select 'alice token', token from public.create_connection_token();
reset role;

-- Tests -----------------------------------------------------------------------

select is(
  pg_temp.scanner_seen_by('alice'),
  null,
  'nobody is shown while the QR code is not scanned'
);

select pg_temp.act_as('bob');
select public.scan_connection_token(
  (select value from kept where name = 'alice token')
);
reset role;

select is(
  pg_temp.scanner_seen_by('alice'),
  'Bob',
  'the owner of the QR code sees who scanned it'
);

-- The QR code renews right after the scan, before the screen asked.
select pg_temp.act_as('alice');
select public.create_connection_token();
reset role;

select is(
  pg_temp.scanner_seen_by('alice'),
  'Bob',
  'a new QR code keeps the scanned one, which still tells who scanned it'
);
select is(
  (select used_by from public.connection_tokens
   where token = (select value from kept where name = 'alice token')),
  pg_temp.user_id('bob'),
  'the token keeps who used it'
);
select is(
  pg_temp.scanner_seen_by('eve'),
  null,
  'nobody else learns who scanned it'
);
select is(
  pg_temp.scanner_seen_by('bob'),
  null,
  'not even the scanner, who does not own the token'
);

insert into public.blocks (blocker_id, blocked_id)
values (pg_temp.user_id('bob'), pg_temp.user_id('alice'));

select is(
  pg_temp.scanner_seen_by('alice'),
  null,
  'someone who then blocked the owner is no longer shown'
);
select ok(
  not has_function_privilege(
    'anon', 'public.connection_token_scan(text)', 'execute'
  ),
  'signed-out users cannot ask'
);

select * from finish();

rollback;
