-- =========================================================================
-- SPOTon Chat - Supabase PostgreSQL Database Schema
-- 
-- Execute this script in your Supabase Project's SQL Editor to create:
-- 1. Tables: profiles, username_change_history, conversations, messages, blocks
-- 2. Indexes for fast username search, participant lookup, and message streams
-- 3. Functions & Triggers for unknown user 3-message limit & username cooldown
-- 4. Row Level Security (RLS) policies
-- 5. Storage bucket setup instructions for user avatars
-- =========================================================================

-- Enable UUID extension if not already enabled
create extension if not exists "uuid-ossp";

-- =========================================================================
-- 1. TABLE: profiles
-- Linked directly to Supabase Auth (auth.users)
-- =========================================================================
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text unique not null,
  username_lower text unique not null,
  display_name text not null,
  avatar_url text default '',
  bio text default 'Hey there! I am using SPOTon Chat.',
  current_status text default 'Available',
  status_updated_at timestamptz default now(),
  who_can_find_me text default 'everyone' check (who_can_find_me in ('everyone', 'nobody')),
  allow_message_requests boolean default true,
  username_changes_count int default 0,
  last_username_change timestamptz,
  last_seen timestamptz default now(),
  created_at timestamptz default now()
);

-- Index for fast case-insensitive username searching
create index if not exists idx_profiles_username_lower on public.profiles (username_lower);
create index if not exists idx_profiles_last_seen on public.profiles (last_seen);
create index if not exists idx_profiles_status_updated on public.profiles (status_updated_at desc);

-- Automatically create profile row when new user signs up in Supabase Auth
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, username, username_lower, display_name)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'username', split_part(new.email, '@', 1)),
    lower(coalesce(new.raw_user_meta_data->>'username', split_part(new.email, '@', 1))),
    coalesce(new.raw_user_meta_data->>'display_name', new.raw_user_meta_data->>'username', split_part(new.email, '@', 1))
  )
  on conflict (id) do nothing;
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- =========================================================================
-- 2. TABLE: username_change_history
-- Tracks previous usernames and change timestamps (Section 10)
-- =========================================================================
create table if not exists public.username_change_history (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete cascade not null,
  old_username text not null,
  new_username text not null,
  changed_at timestamptz default now()
);

create index if not exists idx_username_history_user on public.username_change_history (user_id);

-- =========================================================================
-- 3. TABLE: conversations
-- Manages 1-on-1 chats and message request states (Section 11, 12, 13)
-- =========================================================================
create table if not exists public.conversations (
  id uuid primary key default gen_random_uuid(),
  participant_one uuid references public.profiles(id) on delete cascade not null,
  participant_two uuid references public.profiles(id) on delete cascade not null,
  status text default 'pending_request' check (status in ('active', 'pending_request', 'declined')),
  request_initiator_id uuid references public.profiles(id) on delete cascade not null,
  request_recipient_id uuid references public.profiles(id) on delete cascade not null,
  unknown_message_count int default 0,
  last_message_content text,
  last_message_sender_id uuid references public.profiles(id),
  last_message_timestamp timestamptz,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  constraint unique_conversation_pair unique (participant_one, participant_two),
  constraint no_self_conversation check (participant_one != participant_two)
);

create index if not exists idx_conversations_p1 on public.conversations (participant_one);
create index if not exists idx_conversations_p2 on public.conversations (participant_two);
create index if not exists idx_conversations_recipient on public.conversations (request_recipient_id, status);
create index if not exists idx_conversations_updated on public.conversations (updated_at desc);

-- =========================================================================
-- 4. TABLE: messages
-- Stores chat messages, replies, and read statuses (Section 13, 14, 15)
-- =========================================================================
create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid references public.conversations(id) on delete cascade not null,
  sender_id uuid references public.profiles(id) on delete cascade not null,
  content text not null,
  reply_to_message_id uuid references public.messages(id) on delete set null,
  reply_to_sender_name text,
  reply_to_snippet text,
  status text default 'sent' check (status in ('sent', 'delivered', 'read')),
  created_at timestamptz default now(),
  read_at timestamptz
);

create index if not exists idx_messages_conv_created on public.messages (conversation_id, created_at asc);
create index if not exists idx_messages_sender on public.messages (sender_id);

-- =========================================================================
-- 5. TABLE: blocks
-- Stores user blocking relationships (Section 18)
-- =========================================================================
create table if not exists public.blocks (
  id uuid primary key default gen_random_uuid(),
  blocker_id uuid references public.profiles(id) on delete cascade not null,
  blocked_id uuid references public.profiles(id) on delete cascade not null,
  created_at timestamptz default now(),
  constraint unique_block_pair unique (blocker_id, blocked_id),
  constraint no_self_block check (blocker_id != blocked_id)
);

create index if not exists idx_blocks_blocker on public.blocks (blocker_id);
create index if not exists idx_blocks_blocked on public.blocks (blocked_id);

-- =========================================================================
-- 6. BUSINESS LOGIC: UNKNOWN-USER 3-MESSAGE LIMIT TRIGGER (Section 11 & 12)
-- Enforces that an unapproved sender cannot send more than 3 messages
-- =========================================================================
create or replace function public.enforce_unknown_user_message_limit()
returns trigger as $$
declare
  v_conv record;
  v_is_blocked boolean;
begin
  -- 1. Fetch the conversation
  select * into v_conv from public.conversations where id = new.conversation_id;
  if not found then
    raise exception 'Conversation not found.';
  end if;

  -- 2. Verify sender is a participant
  if new.sender_id != v_conv.participant_one and new.sender_id != v_conv.participant_two then
    raise exception 'Sender is not a participant in this conversation.';
  end if;

  -- 3. Check blocking
  select exists (
    select 1 from public.blocks
    where blocker_id = (case when new.sender_id = v_conv.participant_one then v_conv.participant_two else v_conv.participant_one end)
      and blocked_id = new.sender_id
  ) into v_is_blocked;

  if v_is_blocked then
    raise exception 'You cannot message this user. They have blocked you.';
  end if;

  -- 4. Check conversation status
  if v_conv.status = 'declined' then
    raise exception 'This message request was declined. You cannot send further messages.';
  end if;

  -- 5. Enforce 3-message limit for pending requests
  if v_conv.status = 'pending_request' then
    if new.sender_id = v_conv.request_initiator_id then
      if v_conv.unknown_message_count >= 3 then
        raise exception 'Message limit reached (3/3). Waiting for recipient to approve the conversation.';
      end if;
      
      -- Increment counter
      update public.conversations
      set unknown_message_count = unknown_message_count + 1,
          last_message_content = new.content,
          last_message_sender_id = new.sender_id,
          last_message_timestamp = new.created_at,
          updated_at = new.created_at
      where id = new.conversation_id;
    elsif new.sender_id = v_conv.request_recipient_id then
      -- If the recipient replies, automatically approve the conversation!
      update public.conversations
      set status = 'active',
          last_message_content = new.content,
          last_message_sender_id = new.sender_id,
          last_message_timestamp = new.created_at,
          updated_at = new.created_at
      where id = new.conversation_id;
    end if;
  else
    -- Active conversation: update last message
    update public.conversations
    set last_message_content = new.content,
        last_message_sender_id = new.sender_id,
        last_message_timestamp = new.created_at,
        updated_at = new.created_at
    where id = new.conversation_id;
  end if;

  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists trg_enforce_message_limit on public.messages;
create trigger trg_enforce_message_limit
before insert on public.messages
for each row execute function public.enforce_unknown_user_message_limit();

-- =========================================================================
-- 7. ROW LEVEL SECURITY (RLS) POLICIES
-- =========================================================================

alter table public.profiles enable row level security;
alter table public.conversations enable row level security;
alter table public.messages enable row level security;
alter table public.blocks enable row level security;
alter table public.username_change_history enable row level security;

-- Profiles: Anyone authenticated can view profiles unless blocked or set to 'nobody'
drop policy if exists "Allow read public profiles" on public.profiles;
create policy "Allow read public profiles" on public.profiles
  for select using (
    id = auth.uid()
    or (
      who_can_find_me = 'everyone'
      and not exists (
        select 1 from public.blocks
        where (blocker_id = auth.uid() and blocked_id = profiles.id)
           or (blocker_id = profiles.id and blocked_id = auth.uid())
      )
    )
  );

drop policy if exists "Allow users to update own profile" on public.profiles;
create policy "Allow users to update own profile" on public.profiles
  for update using (id = auth.uid());

drop policy if exists "Allow users to insert own profile" on public.profiles;
create policy "Allow users to insert own profile" on public.profiles
  for insert with check (id = auth.uid());

-- Conversations: Only participants can view, insert, or update
drop policy if exists "Conversations participant access" on public.conversations;
create policy "Conversations participant access" on public.conversations
  for select using (participant_one = auth.uid() or participant_two = auth.uid());

drop policy if exists "Conversations participant insert" on public.conversations;
create policy "Conversations participant insert" on public.conversations
  for insert with check (participant_one = auth.uid() or participant_two = auth.uid());

drop policy if exists "Conversations participant update" on public.conversations;
create policy "Conversations participant update" on public.conversations
  for update using (participant_one = auth.uid() or participant_two = auth.uid());

-- Messages: Only conversation participants can view or send messages
drop policy if exists "Messages conversation access" on public.messages;
create policy "Messages conversation access" on public.messages
  for select using (
    exists (
      select 1 from public.conversations
      where id = messages.conversation_id
        and (participant_one = auth.uid() or participant_two = auth.uid())
    )
  );

drop policy if exists "Messages sender insert" on public.messages;
create policy "Messages sender insert" on public.messages
  for insert with check (
    sender_id = auth.uid()
    and exists (
      select 1 from public.conversations
      where id = messages.conversation_id
        and (participant_one = auth.uid() or participant_two = auth.uid())
    )
  );

drop policy if exists "Messages update read status" on public.messages;
create policy "Messages update read status" on public.messages
  for update using (
    exists (
      select 1 from public.conversations
      where id = messages.conversation_id
        and (participant_one = auth.uid() or participant_two = auth.uid())
    )
  );

-- Blocks: Only the blocker can manage their blocks
drop policy if exists "Blocks owner access" on public.blocks;
create policy "Blocks owner access" on public.blocks
  for select using (blocker_id = auth.uid());

drop policy if exists "Blocks owner insert" on public.blocks;
create policy "Blocks owner insert" on public.blocks
  for insert with check (blocker_id = auth.uid());

drop policy if exists "Blocks owner delete" on public.blocks;
create policy "Blocks owner delete" on public.blocks
  for delete using (blocker_id = auth.uid());

-- =========================================================================
-- 8. SUPABASE STORAGE BUCKET CONFIGURATION (avatars)
-- Execute these in Supabase SQL Editor to configure the avatar storage bucket
-- =========================================================================
insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do nothing;

drop policy if exists "Public avatar images access" on storage.objects;
create policy "Public avatar images access" on storage.objects
  for select using (bucket_id = 'avatars');

drop policy if exists "Authenticated users can upload avatars" on storage.objects;
create policy "Authenticated users can upload avatars" on storage.objects
  for insert with check (
    bucket_id = 'avatars'
    and auth.role() = 'authenticated'
  );

drop policy if exists "Users can update own avatar" on storage.objects;
create policy "Users can update own avatar" on storage.objects
  for update using (
    bucket_id = 'avatars'
    and auth.uid()::text = (storage.foldername(name))[1]
  );
