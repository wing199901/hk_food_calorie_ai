-- ============================================================
-- FitCalorie – Supabase Database Schema
-- Run this SQL in: Supabase Dashboard → SQL Editor → New Query
-- ============================================================

-- Enable Row Level Security (RLS) helpers
-- Each table is scoped to the authenticated user via user_id = auth.uid()

-- ─────────────────────────────────────────────────────────────
-- 1. user_profiles
-- ─────────────────────────────────────────────────────────────
create table
if not exists public.user_profiles
(
  user_id           uuid primary key references auth.users
(id) on
delete cascade,
  birthdate         date,          -- YYYY-MM-DD
  weight            numeric
(5,2),
  height            numeric
(5,2),
  waistline         numeric
(5,2),
  gender            text,          -- 'male' | 'female' | 'other'
  activity_level    integer default 2, -- 0=sedentary | 1=light | 2=moderate | 3=active | 4=very-active
  calorie_target    integer default 2000,
  last_check_in_date date,         -- date type (YYYY-MM-DD)
  created_at        timestamptz default now
(),
  updated_at        timestamptz default now
()
);

alter table public.user_profiles enable row level security;

create policy "Users can view their own profile"
  on public.user_profiles for
select
  using (auth.uid() = user_id);

create policy "Users can insert their own profile"
  on public.user_profiles for
insert
  with check (auth.uid() =
user_id);

create policy "Users can update their own profile"
  on public.user_profiles for
update
  using (auth.uid()
= user_id);

-- ─────────────────────────────────────────────────────────────
-- 2. body_metrics
-- ─────────────────────────────────────────────────────────────
create table
if not exists public.body_metrics
(
  user_id    uuid not null references auth.users(id) on delete cascade,
  date       date not null,                   -- date type (YYYY-MM-DD)
  weight     numeric(5,2),
  waistline  numeric(5,2),
  bmi        numeric(4,1),
  whtr       numeric(3,2),
  tee        integer,
  created_at timestamptz default now(),
  primary key (user_id, date)
);

alter table public.body_metrics enable row level security;

create policy "Users can view their own metrics"
  on public.body_metrics for
select
  using (auth.uid() = user_id);

create policy "Users can insert their own metrics"
  on public.body_metrics for
insert
  with check (auth.uid() =
user_id);

create policy "Users can update their own metrics"
  on public.body_metrics for
update
  using (auth.uid()
= user_id);

-- ─────────────────────────────────────────────────────────────
-- 3. meal_records  (all diet records: AI-analysed + manual)
-- ─────────────────────────────────────────────────────────────
create table if not exists public.meal_records (
  -- identity
  id              text          primary key,           -- client or server generated UUID
  user_id         uuid          not null references auth.users (id) on delete cascade,
  date            date          not null,              -- YYYY-MM-DD

  -- input
  image_base64    text,                               -- original photo stored as base64

  -- AI output
  items           jsonb         not null default '[]', -- array of food/drink items
  total_calories  integer       not null default 0,
  total_protein   integer                default 0,
  total_carbs     integer                default 0,
  total_fat       integer                default 0,
  total_sugar     integer                default 0,

  -- metadata
  deleted_at      timestamptz,                        -- soft delete
  created_at      timestamptz            default now(),
  updated_at      timestamptz            default now()
);



create index
if not exists meal_records_user_date_idx
  on public.meal_records
(user_id, date);

-- Supports fetchMeals ORDER BY created_at DESC
create index
if not exists meal_records_user_created_idx
  on public.meal_records
(user_id, created_at desc);

alter table public.meal_records enable row level security;

create policy "Users can view their own meal records"
  on public.meal_records for
select
  using (auth.uid() = user_id);

create policy "Users can insert their own meal records"
  on public.meal_records for
insert
  with check (auth.uid() =
user_id);

create policy "Users can update their own meal records"
  on public.meal_records for
update
  using (auth.uid()
= user_id);

create policy "Users can delete their own meal records"
  on public.meal_records for
delete
  using (auth.uid
() = user_id);

-- ─────────────────────────────────────────────────────────────
-- 4. quick_add_items  (用戶自訂快捷食物)
-- ─────────────────────────────────────────────────────────────
create table
if not exists public.quick_add_items
(
  id              text not null,
  user_id         uuid not null references auth.users(id) on delete cascade,
  name            text not null,
  calories        integer not null default 0,
  protein         integer default 0,
  carbs           integer default 0,
  fat             integer default 0,
  sugar           integer default 0,
  icon            text not null default '🍽️',
  sort_order      integer default 0,
  created_at      timestamptz default now(),
  primary key (user_id, id)
);

alter table public.quick_add_items enable row level security;

create policy "Users can view their own quick add items"
  on public.quick_add_items for select
  using (auth.uid() = user_id);

create policy "Users can insert their own quick add items"
  on public.quick_add_items for insert
  with check (auth.uid() = user_id);

create policy "Users can update their own quick add items"
  on public.quick_add_items for update
  using (auth.uid() = user_id);

create policy "Users can delete their own quick add items"
  on public.quick_add_items for delete
  using (auth.uid() = user_id);

-- Seed default quick-add items for new users via trigger
create or replace function public.seed_quick_add_items()
returns trigger language plpgsql security definer
set search_path = ''
as $$
begin
  insert into public.quick_add_items (id, user_id, name, calories, protein, carbs, fat, sugar, icon, sort_order)
  values
    ('default-white-rice',     new.id, 'White Rice',       230,  4, 50,  0,  0, '🍚', 0),
    ('default-egg',            new.id, 'Egg',               78,  6,  0,  5,  0, '🥚', 1),
    ('default-banana',         new.id, 'Banana',           105,  1, 27,  0, 14, '🍌', 2),
    ('default-toast',          new.id, 'Toast (2 slices)', 160,  6, 30,  2,  4, '🍞', 3),
    ('default-coffee',         new.id, 'Coffee with Milk', 120,  4, 10,  6,  8, '☕', 4),
    ('default-chicken-breast', new.id, 'Chicken Breast',   165, 31,  0,  4,  0, '🍗', 5),
    ('default-apple',          new.id, 'Apple',             95,  0, 25,  0, 19, '🍎', 6),
    ('default-greek-yogurt',   new.id, 'Greek Yogurt',     100, 10,  6,  3,  5, '🥛', 7);
  return new;
end;
$$;

create or replace trigger on_auth_user_created_seed_quick_add
  after insert on auth.users
  for each row
execute procedure public.seed_quick_add_items();

-- ─────────────────────────────────────────────────────────────
-- 5. Helper: auto-update updated_at
-- ─────────────────────────────────────────────────────────────
create or replace function public.handle_updated_at()
returns trigger language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace trigger on_user_profiles_updated
  before update on public.user_profiles
  for each row
  execute procedure public.handle_updated_at();

create or replace trigger on_meal_records_updated
  before update on public.meal_records
  for each row
  execute procedure public.handle_updated_at();
