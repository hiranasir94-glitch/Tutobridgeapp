-- Structured teaching mode, immediate availability and area of expertise on teacher profiles, with indexes for filtering.
-- The teacher table in this project is public.teacher_profiles (name and photo live in public.profiles).
--
-- teaching_modes: 'online' | 'home_academy' (Home Academy / Tuition Center) | 'private_home' (Private Home Tuition).
--   home_academy and private_home are the same thing as the existing available_at_teacher_home and
--   available_at_student_home flags. A trigger keeps the two representations in step, so older code, the booking
--   form and the map keep working. 'At School' (school hiring) stays its own flag, available_at_school.
-- expertise_categories: stable slugs, shown to users with the labels listed in the app.

-- ---------------------------------------------------------------------------------------------------------
-- 1. columns and value checks
-- ---------------------------------------------------------------------------------------------------------
alter table public.teacher_profiles
  add column teaching_modes           text[]  not null default '{}',
  add column is_immediately_available boolean not null default false,
  add column expertise_categories     text[]  not null default '{}',
  add constraint teaching_modes_valid
    check (teaching_modes <@ array['online', 'home_academy', 'private_home']::text[]),
  add constraint expertise_categories_valid
    check (expertise_categories <@ array['early_years', 'primary', 'middle_school', 'high_school', 'higher_secondary',
                                         'university_test_prep', 'quran_nazra', 'sports', 'aitchison_prep']::text[]);

-- Online lessons are paid for like home tuition, so they need a fee too. NOT VALID so older rows do not block this.
alter table public.teacher_profiles
  add constraint online_has_rate check (not ('online' = any (teaching_modes)) or rate_amount is not null) not valid;

-- Existing teachers: carry their current home modes over.
update public.teacher_profiles
   set teaching_modes = array_remove(array[
         case when available_at_teacher_home then 'home_academy' end,
         case when available_at_student_home then 'private_home' end], null);

-- ---------------------------------------------------------------------------------------------------------
-- 2. keep teaching_modes and the two legacy flags in step (whichever side the writer changed wins)
-- ---------------------------------------------------------------------------------------------------------
create or replace function public.sync_teaching_modes() returns trigger
language plpgsql set search_path = '' as $$
declare
  from_modes boolean;
begin
  if tg_op = 'INSERT' then
    from_modes := cardinality(new.teaching_modes) > 0;
  else
    from_modes := new.teaching_modes is distinct from old.teaching_modes;
  end if;

  if from_modes then
    new.available_at_teacher_home := 'home_academy' = any (new.teaching_modes);
    new.available_at_student_home := 'private_home'  = any (new.teaching_modes);
  else
    -- flags were written: rebuild the home entries, keep 'online' as it was
    new.teaching_modes := array_remove(array[
        case when 'online' = any (new.teaching_modes) then 'online' end,
        case when new.available_at_teacher_home then 'home_academy' end,
        case when new.available_at_student_home then 'private_home' end], null);
  end if;
  return new;
end $$;

create trigger teacher_profiles_sync_modes
  before insert or update on public.teacher_profiles
  for each row execute function public.sync_teaching_modes();

-- ---------------------------------------------------------------------------------------------------------
-- 3. indexes for the search filters (overlaps / contains use GIN) and the "available now" board
-- ---------------------------------------------------------------------------------------------------------
create index teacher_profiles_modes_gin     on public.teacher_profiles using gin (teaching_modes);
create index teacher_profiles_expertise_gin on public.teacher_profiles using gin (expertise_categories);
create index teacher_profiles_board_idx     on public.teacher_profiles (is_immediately_available desc, rating_avg desc)
  where verification_status = 'verified' and is_accepting_students;

-- ---------------------------------------------------------------------------------------------------------
-- 4. parents can request a trial with an online teacher: allow 'online' as a booking mode
-- ---------------------------------------------------------------------------------------------------------
alter table public.bookings drop constraint bookings_teaching_mode_check;
alter table public.bookings add constraint bookings_teaching_mode_check
  check (teaching_mode in ('at_school', 'at_student_home', 'at_teacher_home', 'online'));

drop policy "bookings: parent insert" on public.bookings;
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
          or (teaching_mode = 'at_teacher_home' and tp.available_at_teacher_home)
          or (teaching_mode = 'online'          and 'online' = any (tp.teaching_modes)))));
