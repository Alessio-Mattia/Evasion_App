-- Messaging between friends.
--
-- A conversation is private (two friends) for now; the tables are ready for
-- group conversations later. Messages are text only, at most 2,000
-- characters (BusinessRules.messageMaxLength), with no quota.
--
-- Only friends can write to each other. After a friend is removed, the
-- history stays readable but nobody can write; a block hides the
-- conversation for both. Each user sees their own unread count only: the
-- other never learns whether a message was read. A user can delete their own
-- messages, which then show as deleted for both; nobody can edit them.
--
-- Messages are readable through Row Level Security, so that the app gets new
-- ones live with Supabase Realtime, which applies the same policies.

-- Tables ---------------------------------------------------------------------

create table public.conversations (
  id uuid primary key default gen_random_uuid(),
  kind text not null default 'private' check (kind in ('private', 'group')),
  -- The two members of a private conversation, stored once per pair.
  user_a uuid references auth.users (id) on delete cascade,
  user_b uuid references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  check (
    (kind = 'private' and user_a is not null and user_b is not null
      and user_a < user_b)
    or (kind = 'group' and user_a is null and user_b is null)
  ),
  unique (user_a, user_b)
);

create table public.conversation_members (
  conversation_id uuid not null
    references public.conversations (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  joined_at timestamptz not null default now(),
  -- Messages after this one are unread, for this member only.
  last_read_at timestamptz not null default now(),
  primary key (conversation_id, user_id)
);

create index conversation_members_user_id_idx on public.conversation_members
  (user_id);

create table public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null
    references public.conversations (id) on delete cascade,
  sender_id uuid not null references auth.users (id) on delete cascade,
  -- Null once deleted by its sender.
  body text check (
    body is null or (btrim(body) <> '' and char_length(body) <= 2000)
  ),
  created_at timestamptz not null default now(),
  deleted_at timestamptz,
  check ((body is null) = (deleted_at is not null))
);

create index messages_conversation_id_idx on public.messages
  (conversation_id, created_at);

-- Access ---------------------------------------------------------------------

alter table public.conversations enable row level security;
alter table public.conversation_members enable row level security;
alter table public.messages enable row level security;

revoke all on public.conversations from anon, authenticated;
revoke all on public.conversation_members from anon, authenticated;
revoke all on public.messages from anon, authenticated;

-- Whether the signed-in user can read the conversation conversation_id: a
-- member, and for a private one, no block either way.
create function private.can_read_conversation(conversation_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.conversation_members as member
    join public.conversations as conversation
      on conversation.id = member.conversation_id
    where member.conversation_id = can_read_conversation.conversation_id
      and member.user_id = (select auth.uid())
      and (
        conversation.kind <> 'private'
        or not private.is_blocked(conversation.user_a, conversation.user_b)
      )
  );
$$;

revoke all on function private.can_read_conversation(uuid) from public;
grant execute on function private.can_read_conversation(uuid)
  to authenticated;

-- Conversations and members are used through the functions below.
create policy "Conversations are not accessible from the app"
  on public.conversations for all to anon, authenticated
  using (false) with check (false);

create policy "Conversation members are not accessible from the app"
  on public.conversation_members for all to anon, authenticated
  using (false) with check (false);

-- Messages are read directly, for Realtime; they are written only through
-- send_message and delete_message.
grant select on public.messages to authenticated;

create policy "Members can read the messages of their conversations"
  on public.messages for select
  to authenticated
  using (private.can_read_conversation(conversation_id));

-- Opening a conversation -----------------------------------------------------

-- The private conversation of the signed-in user with friend_id, created the
-- first time. Fails when friend_id is not a friend (insufficient_privilege).
create function public.open_private_conversation(friend_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
#variable_conflict use_variable
declare
  me uuid := (select auth.uid());
  found_id uuid;
begin
  if not exists (
    select 1 from public.profiles where id = me and is_complete
  ) or not private.are_friends(me, friend_id) then
    raise exception 'only a friend can be written to'
      using errcode = 'insufficient_privilege';
  end if;

  insert into public.conversations (kind, user_a, user_b)
  values ('private', least(me, friend_id), greatest(me, friend_id))
  on conflict (user_a, user_b) do nothing
  returning id into found_id;

  if found_id is null then
    select conversation.id into found_id
    from public.conversations as conversation
    where conversation.user_a = least(me, friend_id)
      and conversation.user_b = greatest(me, friend_id);
  else
    insert into public.conversation_members (conversation_id, user_id)
    values (found_id, me), (found_id, friend_id);
  end if;

  return found_id;
end;
$$;

-- Sending and deleting -------------------------------------------------------

-- Sends body to the conversation conversation_id and returns the message id.
-- Fails when the user cannot write there: not a member, or in a private
-- conversation with someone who is no longer a friend or a block
-- (insufficient_privilege); and for an empty or too long text
-- (check_violation).
create function public.send_message(conversation_id uuid, body text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
#variable_conflict use_variable
declare
  me uuid := (select auth.uid());
  conversation public.conversations;
  sent_body text := btrim(body);
  new_id uuid;
begin
  select * into conversation
  from public.conversations as existing
  where existing.id = conversation_id;

  if conversation.id is null
    or not exists (
      select 1 from public.conversation_members as member
      where member.conversation_id = conversation_id and member.user_id = me
    )
    or (
      conversation.kind = 'private'
      and not private.are_friends(conversation.user_a, conversation.user_b)
    )
  then
    raise exception 'the user cannot write in this conversation'
      using errcode = 'insufficient_privilege';
  end if;

  if sent_body is null or sent_body = '' or char_length(sent_body) > 2000 then
    raise exception 'a message has from 1 to 2000 characters'
      using errcode = 'check_violation';
  end if;

  insert into public.messages (conversation_id, sender_id, body)
  values (conversation_id, me, sent_body)
  returning id into new_id;

  -- Their own message is read.
  update public.conversation_members as member
  set last_read_at = now()
  where member.conversation_id = conversation_id and member.user_id = me;

  return new_id;
end;
$$;

-- Deletes a message of the signed-in user: it then shows as deleted for both.
-- A message of someone else, or already deleted, is left as it is.
create function public.delete_message(message_id uuid)
returns void
language sql
security definer
set search_path = ''
as $$
  update public.messages
  set body = null, deleted_at = now()
  where id = message_id
    and sender_id = (select auth.uid())
    and deleted_at is null;
$$;

-- Reading --------------------------------------------------------------------

-- Marks the conversation conversation_id as read by the signed-in user.
create function public.mark_conversation_read(conversation_id uuid)
returns void
language sql
security definer
set search_path = ''
as $$
  update public.conversation_members as member
  set last_read_at = now()
  where member.conversation_id = mark_conversation_read.conversation_id
    and member.user_id = (select auth.uid());
$$;

-- The signed-in user's private conversations, the most recently active
-- first: the other person, whether the user can still write, the last
-- message, and the user's own unread count. Conversations with someone the
-- user can no longer see (a block, an incomplete profile) are left out.
create function public.my_conversations()
returns table (
  conversation_id uuid,
  user_id uuid,
  display_name text,
  avatar_path text,
  can_write boolean,
  last_message_body text,
  last_message_is_mine boolean,
  last_message_at timestamptz,
  unread_count integer
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    conversation.id,
    person.id,
    person.display_name,
    person.avatar_path,
    private.are_friends(conversation.user_a, conversation.user_b),
    last_message.body,
    last_message.sender_id = (select auth.uid()),
    coalesce(last_message.created_at, conversation.created_at),
    (
      select count(*)::integer
      from public.messages as unread
      where unread.conversation_id = conversation.id
        and unread.sender_id <> (select auth.uid())
        and unread.deleted_at is null
        and unread.created_at > member.last_read_at
    )
  from public.conversation_members as member
  join public.conversations as conversation
    on conversation.id = member.conversation_id
  cross join lateral public.get_public_profile(
    case
      when conversation.user_a = (select auth.uid()) then conversation.user_b
      else conversation.user_a
    end
  ) as person
  left join lateral (
    select message.body, message.sender_id, message.created_at
    from public.messages as message
    where message.conversation_id = conversation.id
    order by message.created_at desc
    limit 1
  ) as last_message on true
  where member.user_id = (select auth.uid())
    and conversation.kind = 'private'
  order by coalesce(last_message.created_at, conversation.created_at) desc;
$$;

-- Access to the functions ----------------------------------------------------

revoke all on function public.open_private_conversation(uuid)
  from public, anon;
revoke all on function public.send_message(uuid, text) from public, anon;
revoke all on function public.delete_message(uuid) from public, anon;
revoke all on function public.mark_conversation_read(uuid) from public, anon;
revoke all on function public.my_conversations() from public, anon;

grant execute on function public.open_private_conversation(uuid)
  to authenticated;
grant execute on function public.send_message(uuid, text) to authenticated;
grant execute on function public.delete_message(uuid) to authenticated;
grant execute on function public.mark_conversation_read(uuid)
  to authenticated;
grant execute on function public.my_conversations() to authenticated;

-- Live messages --------------------------------------------------------------

-- New and deleted messages reach the app through Realtime, filtered by the
-- policy above.
alter publication supabase_realtime add table public.messages;
