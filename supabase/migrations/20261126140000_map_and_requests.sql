-- Map on both home screens: teachers and tuition centres around a parent, and open tuition requests around a teacher.
-- Exact positions are never exposed: every position returned here is snapped to a grid of about 1 km.

-- ---------------------------------------------------------------------------------------------------------
-- 1. tuition requests: a parent says what they are looking for. Visible to verified teachers through
--    map_requests() only (name reduced to a first name, position snapped to the grid, no address or phone).
-- ---------------------------------------------------------------------------------------------------------
create table public.tuition_requests (
  id         uuid primary key default gen_random_uuid(),
  parent_id  uuid not null references public.profiles (id) on delete cascade,
  subject    text not null check (char_length(btrim(subject)) between 1 and 60),
  curriculum text check (curriculum is null or char_length(curriculum) <= 60),
  grade      text check (grade is null or char_length(grade) <= 60),
  note       text check (note is null or char_length(note) <= 300),
  status     text not null default 'open' check (status in ('open', 'closed')),
  created_at timestamptz not null default now()
);
create index tuition_requests_open_idx on public.tuition_requests (status, created_at desc);
create index tuition_requests_parent_idx on public.tuition_requests (parent_id, created_at desc);

alter table public.tuition_requests enable row level security;
revoke all on public.tuition_requests from anon, authenticated;
grant select on public.tuition_requests to authenticated;
grant insert (parent_id, subject, curriculum, grade, note) on public.tuition_requests to authenticated;
grant update (status) on public.tuition_requests to authenticated;

create policy "requests: parent reads own" on public.tuition_requests for select to authenticated
  using (parent_id = auth.uid());
create policy "requests: parent creates own" on public.tuition_requests for insert to authenticated
  with check (parent_id = auth.uid()
              and exists (select 1 from public.profiles where id = auth.uid() and role = 'parent')
              and (select count(*) from public.tuition_requests r where r.parent_id = auth.uid() and r.status = 'open') < 3);
create policy "requests: parent updates own" on public.tuition_requests for update to authenticated
  using (parent_id = auth.uid()) with check (parent_id = auth.uid());

-- ---------------------------------------------------------------------------------------------------------
-- 2. what a parent sees: verified teachers who are accepting students, snapped to ~1 km.
--    kind = 'centre' for teachers who teach at their own place, otherwise 'teacher'.
-- ---------------------------------------------------------------------------------------------------------
create or replace function public.map_teachers()
returns table (teacher_id uuid, name text, kind text, subjects text[], curricula text[], is_star boolean, rating numeric,
               lat numeric, lng numeric, distance_km numeric)
language sql stable security definer set search_path = '' as $$
  select tp.id, p.full_name,
         case when tp.available_at_teacher_home then 'centre' else 'teacher' end,
         tp.subjects, tp.curricula, tp.is_star_teacher, tp.rating_avg,
         round(p.current_lat::numeric, 2), round(p.current_lng::numeric, 2),
         case when me.current_lat is null or me.current_lng is null then null
              else (round(2 * 6371 * 2 * asin(sqrt(least(1,
                     sin(radians(p.current_lat - me.current_lat) / 2) ^ 2
                     + cos(radians(me.current_lat)) * cos(radians(p.current_lat))
                       * sin(radians(p.current_lng - me.current_lng) / 2) ^ 2)))) / 2)::numeric end
  from public.profiles me
  join public.teacher_profiles tp on tp.verification_status = 'verified' and tp.is_accepting_students
  join public.profiles p on p.id = tp.id
  where me.id = auth.uid() and me.role = 'parent'
    and p.current_lat is not null and p.current_lng is not null
  order by 10 nulls last
  limit 150;
$$;

-- ---------------------------------------------------------------------------------------------------------
-- 3. what a verified teacher sees: open requests from parents with a saved location, snapped to ~1 km.
-- ---------------------------------------------------------------------------------------------------------
create or replace function public.map_requests()
returns table (request_id uuid, parent_first_name text, subject text, curriculum text, grade text, note text,
               area text, lat numeric, lng numeric, distance_km numeric, created_at timestamptz)
language sql stable security definer set search_path = '' as $$
  select r.id, split_part(btrim(p.full_name), ' ', 1), r.subject, r.curriculum, r.grade, r.note,
         p.current_location_label,
         round(p.current_lat::numeric, 2), round(p.current_lng::numeric, 2),
         case when me.current_lat is null or me.current_lng is null then null
              else (round(2 * 6371 * 2 * asin(sqrt(least(1,
                     sin(radians(p.current_lat - me.current_lat) / 2) ^ 2
                     + cos(radians(me.current_lat)) * cos(radians(p.current_lat))
                       * sin(radians(p.current_lng - me.current_lng) / 2) ^ 2)))) / 2)::numeric end,
         r.created_at
  from public.profiles me
  join public.teacher_profiles mt on mt.id = me.id and mt.verification_status = 'verified'
  join public.tuition_requests r on r.status = 'open' and r.created_at > now() - interval '60 days'
  join public.profiles p on p.id = r.parent_id
  where me.id = auth.uid() and me.role = 'teacher'
    and p.current_lat is not null and p.current_lng is not null
  order by 10 nulls last, r.created_at desc
  limit 150;
$$;

-- A verified teacher reaches out to a parent whose request is open. Returns the (existing or new) conversation.
create or replace function public.connect_to_request(p_request_id uuid) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  pid uuid;
  cid uuid;
begin
  if auth.uid() is null or not exists (select 1 from public.teacher_profiles where id = auth.uid() and verification_status = 'verified') then
    raise exception 'Only verified teachers can connect to a request' using errcode = '42501';
  end if;
  select parent_id into pid from public.tuition_requests where id = p_request_id and status = 'open';
  if pid is null then
    raise exception 'This request is no longer open' using errcode = 'P0002';
  end if;
  select id into cid from public.conversations where parent_id = pid and teacher_id = auth.uid();
  if cid is null then
    insert into public.conversations (parent_id, teacher_id) values (pid, auth.uid()) returning id into cid;
  end if;
  return cid;
end $$;

revoke execute on function public.map_teachers(), public.map_requests(), public.connect_to_request(uuid) from public, anon;
grant  execute on function public.map_teachers(), public.map_requests(), public.connect_to_request(uuid) to authenticated;
