-- Tutobridge: role-based architecture (parent / teacher / admin), teacher profiles, bookings, RLS and storage.
--
-- Supersedes the earlier prototype tables in 20261125000000_mera_ustaad_teachers.sql (`teachers`,
-- `teacher_reviews`, `search_teachers`). Those are not used by the Flutter app; delete that migration and
-- supabase/seed.sql if you have not applied them anywhere.
--
-- Security notes:
--  * Sign-up metadata can only create 'parent' or 'teacher'. 'admin' is never accepted from the client;
--    promote an admin from the SQL editor: update public.profiles set role = 'admin' where id = '<uuid>';
--  * Parents' phone numbers are not readable through the table. A teacher sees a parent's number only through
--    public.teacher_bookings(), and only after accepting the request.
--  * Teachers cannot change their own verification_status, is_star_teacher, rating_avg or reviews_count.

-- ---------------------------------------------------------------------------------------------------------
-- 1. profiles
-- ---------------------------------------------------------------------------------------------------------
create table public.profiles (
  id           uuid primary key references auth.users (id) on delete cascade,
  role         text not null check (role in ('parent', 'teacher', 'admin')),
  full_name    text not null,
  phone_number text,
  city         text default 'Lahore',
  avatar_url   text,
  created_at   timestamptz not null default now()
);

create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.profiles where id = auth.uid() and role = 'admin');
$$;

-- Creates the profile row when someone signs up. Reads role, full_name and phone_number from the metadata
-- passed to supabase.auth.signUp(data: {...}).
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  requested_role text := lower(coalesce(new.raw_user_meta_data ->> 'role', ''));
begin
  insert into public.profiles (id, role, full_name, phone_number)
  values (
    new.id,
    case when requested_role = 'teacher' then 'teacher' else 'parent' end,
    coalesce(nullif(trim(new.raw_user_meta_data ->> 'full_name'), ''),
             nullif(split_part(coalesce(new.email, ''), '@', 1), ''),
             'New user'),
    nullif(trim(new.raw_user_meta_data ->> 'phone_number'), '')
  );
  return new;
end $$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------------------------------------------
-- 2. teacher_profiles
-- ---------------------------------------------------------------------------------------------------------
create table public.teacher_profiles (
  id                         uuid primary key references public.profiles (id) on delete cascade,
  bio_description            text,
  qualifications             text[] not null default '{}',   -- e.g. 'MPhil HRM - Kinnaird College'
  years_experience           int not null default 0 check (years_experience >= 0),
  subjects                   text[] not null default '{}',
  curricula                  text[] not null default '{}',
  neighborhoods              text[] not null default '{}',

  available_at_school        boolean not null default false,
  estimated_monthly_salary   numeric(12, 2) check (estimated_monthly_salary is null or estimated_monthly_salary >= 0),
  available_at_student_home  boolean not null default false,
  student_home_hourly_rate   numeric(10, 2) check (student_home_hourly_rate is null or student_home_hourly_rate >= 0),
  available_at_teacher_home  boolean not null default false,
  teacher_home_hourly_rate   numeric(10, 2) check (teacher_home_hourly_rate is null or teacher_home_hourly_rate >= 0),

  verification_status        text not null default 'pending' check (verification_status in ('pending', 'verified', 'rejected')),
  cnic_doc_url               text,   -- storage path inside the private teacher_documents bucket, not a link
  degree_doc_url             text,   -- same
  is_accepting_students      boolean not null default true,
  is_star_teacher            boolean not null default false,
  rating_avg                 numeric(3, 2) not null default 0.00 check (rating_avg between 0 and 5),
  reviews_count              int not null default 0 check (reviews_count >= 0),
  updated_at                 timestamptz not null default now(),

  constraint school_mode_has_salary   check (not available_at_school       or estimated_monthly_salary is not null),
  constraint student_home_has_rate    check (not available_at_student_home or student_home_hourly_rate is not null),
  constraint teacher_home_has_rate    check (not available_at_teacher_home or teacher_home_hourly_rate is not null)
);

-- Verification and rating fields belong to admins and the system, not to the teacher.
create or replace function public.guard_teacher_profile() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  -- No uid means a server-side context (service role, SQL editor, migrations). Admins are trusted as well.
  if auth.uid() is not null and not public.is_admin() then
    if tg_op = 'INSERT' then
      new.verification_status := 'pending';
      new.is_star_teacher := false;
      new.rating_avg := 0;
      new.reviews_count := 0;
    else
      new.verification_status := old.verification_status;
      new.is_star_teacher := old.is_star_teacher;
      new.rating_avg := old.rating_avg;
      new.reviews_count := old.reviews_count;
    end if;
  end if;
  new.updated_at := now();
  return new;
end $$;

create trigger guard_teacher_profile
  before insert or update on public.teacher_profiles
  for each row execute function public.guard_teacher_profile();

-- ---------------------------------------------------------------------------------------------------------
-- 3. bookings
-- ---------------------------------------------------------------------------------------------------------
create table public.bookings (
  id                uuid primary key default gen_random_uuid(),
  parent_id         uuid not null references public.profiles (id) on delete cascade,
  teacher_id        uuid not null references public.teacher_profiles (id) on delete cascade,
  student_grade     text,
  subject           text,
  teaching_mode     text not null check (teaching_mode in ('at_school', 'at_student_home', 'at_teacher_home')),
  neighborhood      text,
  proposed_schedule text,
  notes             text,
  status            text not null default 'pending' check (status in ('pending', 'accepted', 'declined', 'completed')),
  created_at        timestamptz not null default now()
);

-- ---------------------------------------------------------------------------------------------------------
-- 4. indexes
-- ---------------------------------------------------------------------------------------------------------
create index teacher_profiles_verification_idx on public.teacher_profiles (verification_status);
create index teacher_profiles_star_idx         on public.teacher_profiles (is_star_teacher);
create index teacher_profiles_accepting_idx    on public.teacher_profiles (is_accepting_students);
create index teacher_profiles_subjects_gin     on public.teacher_profiles using gin (subjects);
create index teacher_profiles_curricula_gin    on public.teacher_profiles using gin (curricula);
create index teacher_profiles_neighborhoods_gin on public.teacher_profiles using gin (neighborhoods);
create index bookings_teacher_idx              on public.bookings (teacher_id, status, created_at desc);
create index bookings_parent_idx               on public.bookings (parent_id, created_at desc);

-- ---------------------------------------------------------------------------------------------------------
-- 5. privileges (column level, so RLS is not the only line of defence)
-- ---------------------------------------------------------------------------------------------------------
revoke all on public.profiles, public.teacher_profiles, public.bookings from anon, authenticated;

-- profiles: phone_number is deliberately not selectable. Use public.get_my_profile() to read your own row.
grant select (id, role, full_name, city, avatar_url, created_at) on public.profiles to authenticated;
grant update (full_name, phone_number, city, avatar_url)         on public.profiles to authenticated;

grant select on public.teacher_profiles to anon, authenticated;
grant insert, update on public.teacher_profiles to authenticated;

grant select on public.bookings to authenticated;
grant insert (parent_id, teacher_id, student_grade, subject, teaching_mode, neighborhood, proposed_schedule, notes)
  on public.bookings to authenticated;
grant update (status) on public.bookings to authenticated;

-- ---------------------------------------------------------------------------------------------------------
-- 6. row level security
-- ---------------------------------------------------------------------------------------------------------
alter table public.profiles         enable row level security;
alter table public.teacher_profiles enable row level security;
alter table public.bookings         enable row level security;

-- profiles
create policy "profiles: read own" on public.profiles
  for select to authenticated using (id = auth.uid());
create policy "profiles: read verified teachers" on public.profiles
  for select to authenticated using (
    exists (select 1 from public.teacher_profiles tp where tp.id = profiles.id and tp.verification_status = 'verified'));
create policy "profiles: admin read all" on public.profiles
  for select to authenticated using (public.is_admin());
create policy "profiles: update own" on public.profiles
  for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

-- teacher_profiles
create policy "teacher_profiles: read verified" on public.teacher_profiles
  for select to anon, authenticated using (verification_status = 'verified');
create policy "teacher_profiles: read own" on public.teacher_profiles
  for select to authenticated using (id = auth.uid());
create policy "teacher_profiles: admin read all" on public.teacher_profiles
  for select to authenticated using (public.is_admin());
create policy "teacher_profiles: insert own" on public.teacher_profiles
  for insert to authenticated with check (
    id = auth.uid()
    and exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'teacher'));
create policy "teacher_profiles: update own" on public.teacher_profiles
  for update to authenticated using (id = auth.uid()) with check (id = auth.uid());
create policy "teacher_profiles: admin update all" on public.teacher_profiles
  for update to authenticated using (public.is_admin()) with check (public.is_admin());

-- bookings
create policy "bookings: parent insert" on public.bookings
  for insert to authenticated with check (
    parent_id = auth.uid()
    and exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'parent')
    and exists (
      select 1 from public.teacher_profiles tp
      where tp.id = teacher_id
        and tp.verification_status = 'verified'
        and tp.is_accepting_students
        and ((teaching_mode = 'at_school'       and tp.available_at_school)
          or (teaching_mode = 'at_student_home' and tp.available_at_student_home)
          or (teaching_mode = 'at_teacher_home' and tp.available_at_teacher_home))));
create policy "bookings: parent read own" on public.bookings
  for select to authenticated using (parent_id = auth.uid());
create policy "bookings: teacher read assigned" on public.bookings
  for select to authenticated using (teacher_id = auth.uid());
create policy "bookings: teacher update status" on public.bookings
  for update to authenticated using (teacher_id = auth.uid()) with check (teacher_id = auth.uid());
create policy "bookings: admin read all" on public.bookings
  for select to authenticated using (public.is_admin());

-- ---------------------------------------------------------------------------------------------------------
-- 7. functions the app calls
-- ---------------------------------------------------------------------------------------------------------
-- Own profile including phone_number.
create or replace function public.get_my_profile() returns setof public.profiles
language sql stable security definer set search_path = '' as $$
  select * from public.profiles where id = auth.uid();
$$;

-- A teacher's incoming requests with the parent's name. The phone number is revealed only once accepted.
create or replace function public.teacher_bookings()
returns table (
  id uuid, parent_id uuid, parent_name text, parent_phone text, student_grade text, subject text,
  teaching_mode text, neighborhood text, proposed_schedule text, notes text, status text, created_at timestamptz)
language sql stable security definer set search_path = '' as $$
  select b.id, b.parent_id, p.full_name,
         case when b.status in ('accepted', 'completed') then p.phone_number end,
         b.student_grade, b.subject, b.teaching_mode, b.neighborhood, b.proposed_schedule, b.notes,
         b.status, b.created_at
  from public.bookings b
  join public.profiles p on p.id = b.parent_id
  where b.teacher_id = auth.uid()
  order by b.created_at desc;
$$;

revoke execute on function public.get_my_profile(), public.teacher_bookings() from public, anon;
grant  execute on function public.get_my_profile(), public.teacher_bookings() to authenticated;

-- Live updates for the teacher dashboard (Realtime respects the RLS policies above).
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    alter publication supabase_realtime add table public.bookings;
  end if;
end $$;

-- ---------------------------------------------------------------------------------------------------------
-- 8. storage buckets and policies
--    Upload paths must start with the user's id: avatars/<uid>/avatar.jpg, teacher_documents/<uid>/cnic.jpg
-- ---------------------------------------------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types) values
  ('avatars', 'avatars', true, 2097152, array['image/jpeg', 'image/png', 'image/webp']),
  ('teacher_documents', 'teacher_documents', false, 5242880, array['image/jpeg', 'image/png', 'image/webp', 'application/pdf'])
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create policy "avatars: public read" on storage.objects
  for select to anon, authenticated using (bucket_id = 'avatars');
create policy "avatars: upload own" on storage.objects
  for insert to authenticated with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "avatars: update own" on storage.objects
  for update to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text)
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "avatars: delete own" on storage.objects
  for delete to authenticated using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "teacher_documents: read own or admin" on storage.objects
  for select to authenticated using (
    bucket_id = 'teacher_documents' and ((storage.foldername(name))[1] = auth.uid()::text or public.is_admin()));
create policy "teacher_documents: upload own" on storage.objects
  for insert to authenticated with check (
    bucket_id = 'teacher_documents' and (storage.foldername(name))[1] = auth.uid()::text
    and exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'teacher'));
create policy "teacher_documents: update own" on storage.objects
  for update to authenticated
  using (bucket_id = 'teacher_documents' and (storage.foldername(name))[1] = auth.uid()::text)
  with check (bucket_id = 'teacher_documents' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "teacher_documents: delete own or admin" on storage.objects
  for delete to authenticated using (
    bucket_id = 'teacher_documents' and ((storage.foldername(name))[1] = auth.uid()::text or public.is_admin()));
