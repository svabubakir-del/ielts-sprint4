-- ============================================================
-- IELTS SPRINT4 — SUPABASE SCHEMA
-- Run this once in the Supabase SQL editor for the Sprint4 project.
-- ============================================================

-- ===================== GROUPS =====================
create table if not exists groups (
  id integer primary key,
  name text not null
);

insert into groups (id, name)
select i, 'Group ' || i
from generate_series(1, 15) as i
on conflict (id) do nothing;

-- ===================== STUDENT PASSCODES (admin pre-generated) =====================
create table if not exists student_passcodes (
  id uuid primary key default gen_random_uuid(),
  passcode text unique not null,
  used boolean not null default false,
  used_by uuid,
  created_at timestamptz default now()
);

-- ===================== STUDENTS =====================
create table if not exists students (
  id uuid primary key default gen_random_uuid(),
  full_name text not null,
  username text unique not null,
  password text not null,           -- the passcode they registered with; doubles as their permanent login password
  group_id integer references groups(id),
  created_at timestamptz default now()
);

alter table student_passcodes
  drop constraint if exists fk_used_by;
alter table student_passcodes
  add constraint fk_used_by foreign key (used_by) references students(id);

-- ===================== TEACHERS / MENTORS =====================
-- Mentors use the same login + table as teachers (per Max2 precedent).
create table if not exists teachers (
  id uuid primary key default gen_random_uuid(),
  full_name text not null,
  username text unique not null,
  password text not null,
  is_mentor boolean not null default false,
  created_at timestamptz default now()
);

create table if not exists mentor_groups (
  mentor_id uuid references teachers(id),
  group_id integer references groups(id),
  primary key (mentor_id, group_id)
);

-- ===================== SUPER ADMIN =====================
create table if not exists admins (
  id uuid primary key default gen_random_uuid(),
  username text unique not null,
  password text not null
);

-- ===================== DAY AVAILABILITY (flat 1-30, no week field) =====================
create table if not exists day_availability (
  day integer primary key,
  is_open boolean not null default false,
  opened_at timestamptz
);

insert into day_availability (day, is_open)
select i, (i = 1)        -- only Day 1 open by default; admin opens the rest from the dashboard
from generate_series(1, 30) as i
on conflict (day) do nothing;

-- ===================== PROGRESS (per student, per day, per task) =====================
create table if not exists progress (
  id uuid primary key default gen_random_uuid(),
  student_id uuid references students(id),
  day integer not null,
  task integer not null,
  completed boolean not null default false,
  completed_at timestamptz,
  unique(student_id, day, task)
);

-- ============================================================
-- ROW LEVEL SECURITY
-- Kept permissive on purpose (matches Max2's lightweight, login-gated
-- approach rather than full Supabase Auth). Anyone with the anon key
-- can read/write these tables directly from the browser. Fine for an
-- internal tool behind a login screen; flag if you want this hardened
-- later (e.g. migrating to real Supabase Auth + per-row policies).
-- ============================================================

alter table groups enable row level security;
alter table student_passcodes enable row level security;
alter table students enable row level security;
alter table teachers enable row level security;
alter table mentor_groups enable row level security;
alter table admins enable row level security;
alter table day_availability enable row level security;
alter table progress enable row level security;

create policy "public read groups" on groups for select using (true);
create policy "public read day_availability" on day_availability for select using (true);
create policy "public update day_availability" on day_availability for update using (true);

create policy "public read passcodes" on student_passcodes for select using (true);
create policy "public update passcodes" on student_passcodes for update using (true);
create policy "public insert passcodes" on student_passcodes for insert with check (true);

create policy "public read students" on students for select using (true);
create policy "public insert students" on students for insert with check (true);

create policy "public read teachers" on teachers for select using (true);
create policy "public read mentor_groups" on mentor_groups for select using (true);
create policy "public read admins" on admins for select using (true);

create policy "public read progress" on progress for select using (true);
create policy "public insert progress" on progress for insert with check (true);
create policy "public update progress" on progress for update using (true);
