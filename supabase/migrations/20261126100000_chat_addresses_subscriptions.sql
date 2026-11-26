-- Chat between parents and teachers, saved addresses, subscription choice, and distance-sorted nearby teachers.

-- ---------------------------------------------------------------------------------------------------------
-- 1. chat: conversations + messages
-- ---------------------------------------------------------------------------------------------------------
create table public.conversations (
  id                   uuid primary key default gen_random_uuid(),
  parent_id            uuid not null references public.profiles (id) on delete cascade,
  teacher_id           uuid not null references public.teacher_profiles (id) on delete cascade,
  created_at           timestamptz not null default now(),
  last_message_at      timestamptz not null default now(),
  last_message_preview text,
  unique (parent_id, teacher_id)
);

create table public.messages (
  id              uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations (id) on delete cascade,
  sender_id       uuid not null references public.profiles (id) on delete cascade,
  body            text not null check (char_length(btrim(body)) between 1 and 2000),
  created_at      timestamptz not null default now()
);

create index conversations_parent_idx  on public.conversations (parent_id, last_message_at desc);
create index conversations_teacher_idx on public.conversations (teacher_id, last_message_at desc);
create index messages_conversation_idx on public.messages (conversation_id, created_at desc);

revoke all on public.conversations, public.messages from anon, authenticated;
grant select on public.conversations to authenticated;                       -- rows are created by start_conversation()
grant select on public.messages to authenticated;
grant insert (conversation_id, sender_id, body) on public.messages to authenticated;

alter table public.conversations enable row level security;
alter table public.messages      enable row level security;

create policy "conversations: participants read" on public.conversations
  for select to authenticated using (parent_id = auth.uid() or teacher_id = auth.uid());

create policy "messages: participants read" on public.messages
  for select to authenticated using (
    exists (select 1 from public.conversations c
            where c.id = messages.conversation_id and (c.parent_id = auth.uid() or c.teacher_id = auth.uid())));
create policy "messages: participants send as themselves" on public.messages
  for insert to authenticated with check (
    sender_id = auth.uid()
    and exists (select 1 from public.conversations c
                where c.id = conversation_id and (c.parent_id = auth.uid() or c.teacher_id = auth.uid())));

-- Keeps the thread list ordered and its preview current.
create or replace function public.touch_conversation() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  update public.conversations
     set last_message_at = new.created_at, last_message_preview = left(btrim(new.body), 120)
   where id = new.conversation_id;
  return new;
end $$;

create trigger messages_touch_conversation
  after insert on public.messages
  for each row execute function public.touch_conversation();

-- A parent connects with a verified teacher; calling again returns the same conversation.
create or replace function public.start_conversation(p_teacher_id uuid) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  cid uuid;
begin
  if auth.uid() is null or not exists (select 1 from public.profiles where id = auth.uid() and role = 'parent') then
    raise exception 'Only parents can start a conversation' using errcode = '42501';
  end if;
  select id into cid from public.conversations where parent_id = auth.uid() and teacher_id = p_teacher_id;
  if cid is not null then
    return cid;
  end if;
  if not exists (select 1 from public.teacher_profiles where id = p_teacher_id and verification_status = 'verified') then
    raise exception 'This teacher is not available' using errcode = 'P0002';
  end if;
  insert into public.conversations (parent_id, teacher_id) values (auth.uid(), p_teacher_id) returning id into cid;
  return cid;
end $$;

-- The caller's threads with the other person's name and picture.
create or replace function public.my_conversations()
returns table (id uuid, other_id uuid, other_name text, other_avatar_url text,
               last_message_preview text, last_message_at timestamptz)
language sql stable security definer set search_path = '' as $$
  select c.id, o.id, o.full_name, o.avatar_url, c.last_message_preview, c.last_message_at
  from public.conversations c
  join public.profiles o on o.id = case when c.parent_id = auth.uid() then c.teacher_id else c.parent_id end
  where c.parent_id = auth.uid() or c.teacher_id = auth.uid()
  order by c.last_message_at desc;
$$;

-- ---------------------------------------------------------------------------------------------------------
-- 2. saved addresses (the current one lives on profiles; use_saved_address copies a saved one there)
-- ---------------------------------------------------------------------------------------------------------
create table public.saved_addresses (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null references public.profiles (id) on delete cascade,
  label          text not null check (char_length(btrim(label)) between 1 and 40),
  address        text not null check (char_length(btrim(address)) between 8 and 300),
  location_label text,
  lat            double precision check (lat is null or lat between -90 and 90),
  lng            double precision check (lng is null or lng between -180 and 180),
  created_at     timestamptz not null default now(),
  constraint saved_addresses_latlng_pair check ((lat is null) = (lng is null))
);
create index saved_addresses_user_idx on public.saved_addresses (user_id, created_at desc);

revoke all on public.saved_addresses from anon, authenticated;
grant select, delete on public.saved_addresses to authenticated;
grant insert (user_id, label, address, location_label, lat, lng) on public.saved_addresses to authenticated;

alter table public.saved_addresses enable row level security;
create policy "saved_addresses: own" on public.saved_addresses
  for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

create or replace function public.use_saved_address(p_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
  update public.profiles p
     set address = s.address, current_location_label = s.location_label, current_lat = s.lat, current_lng = s.lng
    from public.saved_addresses s
   where s.id = p_id and s.user_id = auth.uid() and p.id = auth.uid();
  if not found then
    raise exception 'Address not found' using errcode = 'P0002';
  end if;
end $$;

-- ---------------------------------------------------------------------------------------------------------
-- 3. subscription choice. No payment provider is connected: choosing a paid plan records a request
--    ('pending_payment'); only the free plan is 'active'. Admins and the service role can activate a plan.
-- ---------------------------------------------------------------------------------------------------------
create table public.subscriptions (
  user_id    uuid primary key references public.profiles (id) on delete cascade,
  plan_id    text not null check (plan_id in ('parent_free', 'parent_plus', 'parent_premium',
                                              'teacher_free', 'teacher_pro', 'teacher_featured')),
  status     text not null default 'active' check (status in ('active', 'pending_payment')),
  updated_at timestamptz not null default now()
);

create or replace function public.guard_subscription() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  r text;
  wanted text := case when new.plan_id like 'teacher\_%' then 'teacher' else 'parent' end;
begin
  select role into r from public.profiles where id = new.user_id;
  if r is distinct from wanted then
    raise exception 'That plan is not available for your account' using errcode = '22023';
  end if;
  if auth.uid() is not null and not public.is_admin() then
    new.status := case when new.plan_id like '%\_free' then 'active' else 'pending_payment' end;
  end if;
  new.updated_at := now();
  return new;
end $$;

create trigger guard_subscription
  before insert or update on public.subscriptions
  for each row execute function public.guard_subscription();

revoke all on public.subscriptions from anon, authenticated;
grant select on public.subscriptions to authenticated;
grant insert (user_id, plan_id) on public.subscriptions to authenticated;
grant update (plan_id) on public.subscriptions to authenticated;

alter table public.subscriptions enable row level security;
create policy "subscriptions: read own"   on public.subscriptions for select to authenticated using (user_id = auth.uid());
create policy "subscriptions: insert own" on public.subscriptions for insert to authenticated with check (user_id = auth.uid());
create policy "subscriptions: update own" on public.subscriptions for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ---------------------------------------------------------------------------------------------------------
-- 4. nearby teachers: distance from the caller's saved location, rounded to 0.5 km so a teacher's exact
--    position is never exposed. Callers without a saved location get no rows.
-- ---------------------------------------------------------------------------------------------------------
create or replace function public.nearby_teacher_distances()
returns table (teacher_id uuid, distance_km numeric)
language sql stable security definer set search_path = '' as $$
  select tp.id,
         (round(2 * 6371 * 2 * asin(sqrt(least(1,
            sin(radians(t.current_lat - me.current_lat) / 2) ^ 2
            + cos(radians(me.current_lat)) * cos(radians(t.current_lat))
              * sin(radians(t.current_lng - me.current_lng) / 2) ^ 2)))) / 2)::numeric
  from public.profiles me
  join public.teacher_profiles tp on tp.verification_status = 'verified' and tp.is_accepting_students
  join public.profiles t on t.id = tp.id
  where me.id = auth.uid()
    and me.current_lat is not null and me.current_lng is not null
    and t.current_lat is not null and t.current_lng is not null;
$$;

-- ---------------------------------------------------------------------------------------------------------
-- 5. function privileges and realtime
-- ---------------------------------------------------------------------------------------------------------
revoke execute on function public.start_conversation(uuid), public.my_conversations(), public.use_saved_address(uuid),
                           public.nearby_teacher_distances() from public, anon;
grant  execute on function public.start_conversation(uuid), public.my_conversations(), public.use_saved_address(uuid),
                           public.nearby_teacher_distances() to authenticated;

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    alter publication supabase_realtime add table public.messages;
  end if;
end $$;
