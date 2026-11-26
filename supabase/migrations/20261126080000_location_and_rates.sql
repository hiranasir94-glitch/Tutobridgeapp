-- Parent and teacher addresses with GPS location, and a day/month tuition fee in place of hourly rates.
--
-- Privacy: address and coordinates are NOT selectable from the client (profiles keeps its column-level grants).
-- A user reads their own through get_my_profile(); a teacher sees a parent's address and location only after
-- accepting that parent's request, through teacher_bookings().

-- ---------------------------------------------------------------------------------------------------------
-- 1. profiles: address + current location
-- ---------------------------------------------------------------------------------------------------------
alter table public.profiles
  add column address                text,
  add column current_location_label text,
  add column current_lat            double precision,
  add column current_lng            double precision,
  add constraint profiles_lat_range check (current_lat is null or current_lat between -90 and 90),
  add constraint profiles_lng_range check (current_lng is null or current_lng between -180 and 180),
  add constraint profiles_latlng_pair check ((current_lat is null) = (current_lng is null));

grant update (address, current_location_label, current_lat, current_lng) on public.profiles to authenticated;

-- Parses metadata numbers without ever raising, so a bad value cannot break sign-up.
create or replace function public.safe_float(v text) returns double precision
language plpgsql immutable set search_path = '' as $$
begin
  return v::double precision;
exception when others then
  return null;
end $$;

create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  requested_role text := lower(coalesce(new.raw_user_meta_data ->> 'role', ''));
  lat double precision := public.safe_float(new.raw_user_meta_data ->> 'current_lat');
  lng double precision := public.safe_float(new.raw_user_meta_data ->> 'current_lng');
begin
  -- Keep coordinates only when both are present and in range.
  if lat is null or lng is null or lat not between -90 and 90 or lng not between -180 and 180
     or lat = 'NaN'::double precision or lng = 'NaN'::double precision then
    lat := null;
    lng := null;
  end if;

  insert into public.profiles (id, role, full_name, phone_number, address, current_location_label, current_lat, current_lng)
  values (
    new.id,
    case when requested_role = 'teacher' then 'teacher' else 'parent' end,
    coalesce(nullif(trim(new.raw_user_meta_data ->> 'full_name'), ''),
             nullif(split_part(coalesce(new.email, ''), '@', 1), ''),
             'New user'),
    nullif(trim(new.raw_user_meta_data ->> 'phone_number'), ''),
    left(nullif(trim(new.raw_user_meta_data ->> 'address'), ''), 500),
    left(nullif(trim(new.raw_user_meta_data ->> 'current_location_label'), ''), 200),
    lat,
    lng
  );
  return new;
end $$;

-- ---------------------------------------------------------------------------------------------------------
-- 2. teacher_profiles: remove hourly rates, add current salary and a per-day / per-month tuition fee
-- ---------------------------------------------------------------------------------------------------------
alter table public.teacher_profiles
  drop constraint student_home_has_rate,
  drop constraint teacher_home_has_rate,
  drop column student_home_hourly_rate,
  drop column teacher_home_hourly_rate,
  add column current_salary numeric(12, 2) check (current_salary is null or current_salary >= 0),  -- PKR, optional
  add column rate_type      text check (rate_type in ('per_day', 'per_month')),
  add column rate_amount    numeric(12, 2) check (rate_amount is null or rate_amount > 0),          -- PKR
  add constraint rate_type_and_amount_together check ((rate_type is null) = (rate_amount is null));

-- Home tuition needs a fee. NOT VALID so any earlier test rows do not block the migration; new rows are checked.
alter table public.teacher_profiles
  add constraint home_modes_have_rate
  check (not (available_at_student_home or available_at_teacher_home) or rate_amount is not null) not valid;

-- ---------------------------------------------------------------------------------------------------------
-- 3. teacher_bookings(): parent address and location, revealed only after acceptance
-- ---------------------------------------------------------------------------------------------------------
drop function public.teacher_bookings();

create function public.teacher_bookings()
returns table (
  id uuid, parent_id uuid, parent_name text, parent_phone text, parent_address text,
  parent_location_label text, parent_lat double precision, parent_lng double precision,
  student_grade text, subject text, teaching_mode text, neighborhood text, proposed_schedule text,
  notes text, status text, created_at timestamptz)
language sql stable security definer set search_path = '' as $$
  select b.id, b.parent_id, p.full_name,
         case when b.status in ('accepted', 'completed') then p.phone_number end,
         case when b.status in ('accepted', 'completed') then p.address end,
         case when b.status in ('accepted', 'completed') then p.current_location_label end,
         case when b.status in ('accepted', 'completed') then p.current_lat end,
         case when b.status in ('accepted', 'completed') then p.current_lng end,
         b.student_grade, b.subject, b.teaching_mode, b.neighborhood, b.proposed_schedule, b.notes,
         b.status, b.created_at
  from public.bookings b
  join public.profiles p on p.id = b.parent_id
  where b.teacher_id = auth.uid()
  order by b.created_at desc;
$$;

revoke execute on function public.teacher_bookings() from public, anon;
grant  execute on function public.teacher_bookings() to authenticated;
