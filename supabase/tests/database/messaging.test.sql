begin;

create extension if not exists pgtap with schema extensions;

select plan(30);

-- Fixtures --------------------------------------------------------------------
-- Alice is friends with Bob and Carol; Bob and Carol are not friends.

create temp table people (name text primary key, id uuid not null);
create temp table kept (name text primary key, value uuid);
grant select on people to authenticated;
grant select, insert on kept to authenticated;

create function pg_temp.user_id(person text)
returns uuid
language sql
as $$
  select id from people where name = person;
$$;

create function pg_temp.kept(key text)
returns uuid
language sql
as $$
  select value from kept where name = key;
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

-- Runs sql as person: 'done', or the error code.
create function pg_temp.try(person text, sql text)
returns text
language plpgsql
as $$
begin
  perform pg_temp.act_as(person);
  execute sql;
  reset role;
  return 'done';
exception when others then
  reset role;
  return 'error ' || sqlstate;
end;
$$;

-- What person reads in the conversation of key, as "Name: body" lines.
create function pg_temp.read(person text, key text)
returns text
language plpgsql
as $$
declare
  result text;
begin
  perform pg_temp.act_as(person);
  select string_agg(
      (select initcap(name) from people where id = sender_id) || ': '
        || coalesce(body, '(deleted)'),
      ', ' order by created_at, body)
    into result
  from public.messages
  where conversation_id = pg_temp.kept(key);
  reset role;
  return coalesce(result, 'nothing');
end;
$$;

-- What person sees in their list: "Name unread/can_write" per conversation.
create function pg_temp.list(person text)
returns text
language plpgsql
as $$
declare
  result text;
begin
  perform pg_temp.act_as(person);
  select string_agg(
      display_name || ' ' || unread_count || ' '
        || case when can_write then 'open' else 'closed' end,
      ', ' order by display_name)
    into result
  from public.my_conversations();
  reset role;
  return coalesce(result, 'nothing');
end;
$$;

insert into people (name, id)
select name, gen_random_uuid()
from unnest(array['alice', 'bob', 'carol']) as name;

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

insert into public.friendships (user_a, user_b)
select least(pg_temp.user_id('alice'), pg_temp.user_id(friend)),
  greatest(pg_temp.user_id('alice'), pg_temp.user_id(friend))
from unnest(array['bob', 'carol']) as friend;

-- Opening ---------------------------------------------------------------------

select pg_temp.act_as('alice');
insert into kept
select 'alice-bob', public.open_private_conversation(pg_temp.user_id('bob'));
reset role;

select pg_temp.act_as('bob');
insert into kept
select 'bob-alice', public.open_private_conversation(pg_temp.user_id('alice'));
reset role;

select is(pg_temp.kept('bob-alice'), pg_temp.kept('alice-bob'),
  'two friends share one private conversation, whoever opens it');
select is(
  (select count(*)::int from public.conversation_members
   where conversation_id = pg_temp.kept('alice-bob')),
  2,
  'with both of them as members'
);
select is(
  pg_temp.try('bob', format('select public.open_private_conversation(%L)',
    pg_temp.user_id('carol'))),
  'error 42501',
  'only a friend can be written to'
);

-- Sending and reading ---------------------------------------------------------

select is(
  pg_temp.try('alice', format('select public.send_message(%L, %L)',
    pg_temp.kept('alice-bob'), '  Salut Bob  ')),
  'done',
  'a friend can send a message'
);
select is(
  pg_temp.try('bob', format('select public.send_message(%L, %L)',
    pg_temp.kept('alice-bob'), 'Salut !')),
  'done',
  'the other one can answer'
);
-- The whole test runs at the same instant: spread the messages as in real
-- life. Alice wrote two minutes ago and last read the conversation then; Bob
-- answered a minute ago.
update public.messages
set created_at = now() - case
  when sender_id = pg_temp.user_id('alice') then interval '2 minutes'
  else interval '1 minute'
end;
update public.conversation_members
set last_read_at = now() - interval '2 minutes'
where user_id = pg_temp.user_id('alice');

select is(pg_temp.read('bob', 'alice-bob'), 'Alice: Salut Bob, Bob: Salut !',
  'both read the conversation, the text trimmed');
select is(pg_temp.read('carol', 'alice-bob'), 'nothing',
  'nobody else reads it');
select is(
  pg_temp.try('carol', format('select public.send_message(%L, %L)',
    pg_temp.kept('alice-bob'), 'Coucou')),
  'error 42501',
  'nobody else writes in it'
);
select is(
  pg_temp.try('alice', format('select public.send_message(%L, %L)',
    pg_temp.kept('alice-bob'), '   ')),
  'error 23514',
  'an empty message is refused'
);
select is(
  pg_temp.try('alice', format('select public.send_message(%L, %L)',
    pg_temp.kept('alice-bob'), repeat('a', 2001))),
  'error 23514',
  'a message over 2,000 characters is refused'
);
select is(
  pg_temp.try('alice', format(
    $$insert into public.messages (conversation_id, sender_id, body)
      values (%L, %L, 'Direct')$$,
    pg_temp.kept('alice-bob'), pg_temp.user_id('alice'))),
  'error 42501',
  'messages cannot be inserted directly'
);
select is(
  pg_temp.try('alice', 'update public.messages set body = ''Changed'''),
  'error 42501',
  'nor edited'
);

select pg_temp.act_as('carol');
select throws_ok('select * from public.conversations', '42501', null,
  'conversations cannot be read directly');
select throws_ok('select * from public.conversation_members', '42501', null,
  'nor their members');
reset role;

-- Unread ----------------------------------------------------------------------

-- Bob's answer came after Alice's last read: one unread for her.
select is(pg_temp.list('alice'), 'Bob 1 open',
  'a user sees their own unread count');
select is(pg_temp.list('bob'), 'Alice 0 open',
  'their own messages are not unread');

-- Bob last read the conversation 30 seconds ago.
update public.conversation_members
set last_read_at = now() - interval '30 seconds'
where user_id = pg_temp.user_id('bob');

select pg_temp.act_as('alice');
select public.mark_conversation_read(pg_temp.kept('alice-bob'));
reset role;

select is(pg_temp.list('alice'), 'Bob 0 open',
  'reading the conversation clears the unread count');
select is(
  (select last_read_at from public.conversation_members
   where conversation_id = pg_temp.kept('alice-bob')
     and user_id = pg_temp.user_id('bob')),
  now() - interval '30 seconds',
  'and changes nothing for the other one'
);

select pg_temp.act_as('alice');
select is(
  (select last_message_body || ' / ' || last_message_is_mine::text
   from public.my_conversations()),
  'Salut ! / false',
  'the list shows the last message and who sent it'
);
reset role;

-- Deleting --------------------------------------------------------------------

insert into kept
select 'bob message', id from public.messages where body = 'Salut !';

select is(
  pg_temp.try('alice', format('select public.delete_message(%L)',
    pg_temp.kept('bob message'))),
  'done',
  'deleting someone else''s message does nothing'
);
select is(pg_temp.read('alice', 'alice-bob'), 'Alice: Salut Bob, Bob: Salut !',
  'it is still there');

select pg_temp.try('bob', format('select public.delete_message(%L)',
  pg_temp.kept('bob message')));

select is(pg_temp.read('alice', 'alice-bob'),
  'Alice: Salut Bob, Bob: (deleted)',
  'a deleted message shows as deleted for both');

-- Removed friend and block ----------------------------------------------------

select pg_temp.try('bob', format('select public.remove_friend(%L)',
  pg_temp.user_id('alice')));

select is(pg_temp.read('alice', 'alice-bob'),
  'Alice: Salut Bob, Bob: (deleted)',
  'after a removed friend, the history stays readable');
select is(pg_temp.list('alice'), 'Bob 0 closed',
  'but the conversation is closed');
select is(
  pg_temp.try('alice', format('select public.send_message(%L, %L)',
    pg_temp.kept('alice-bob'), 'Tu es là ?')),
  'error 42501',
  'nobody can write any more'
);

select pg_temp.act_as('alice');
insert into kept
select 'alice-carol',
  public.open_private_conversation(pg_temp.user_id('carol'));
select public.send_message(pg_temp.kept('alice-carol'), 'Hello Carol');
reset role;

insert into public.blocks (blocker_id, blocked_id)
values (pg_temp.user_id('carol'), pg_temp.user_id('alice'));

select is(pg_temp.read('alice', 'alice-carol'), 'nothing',
  'a block hides the conversation for the blocked user');
select is(pg_temp.read('carol', 'alice-carol'), 'nothing',
  'and for the one who blocked');
select is(pg_temp.list('alice'), 'Bob 0 closed',
  'it leaves the list too');

-- Access and Realtime ---------------------------------------------------------

select ok(
  not has_function_privilege(
    'anon', 'public.send_message(uuid, text)', 'execute'
  ),
  'signed-out users cannot send messages'
);
select ok(
  exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and tablename = 'messages'
  ),
  'new messages are published to Realtime'
);

select * from finish();

rollback;
