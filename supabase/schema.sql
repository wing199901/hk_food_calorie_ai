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
  unit_system       text default 'metric', -- 'metric' | 'imperial'
  calorie_target    integer default 2000,
  last_check_in_date date,         -- date type (YYYY-MM-DD)
  created_at        timestamptz default now
(),
  updated_at        timestamptz default now
()
);

alter table public.user_profiles enable row level security;

create policy "Users can view their own profile"
  on public.user_profiles for select
  using ((select auth.uid()) = user_id);

create policy "Users can insert their own profile"
  on public.user_profiles for insert
  with check ((select auth.uid()) = user_id);

create policy "Users can update their own profile"
  on public.user_profiles for update
  using ((select auth.uid()) = user_id);

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
  created_at timestamptz not null default now(),
  primary key (user_id, date, created_at)
);

create index
if not exists body_metrics_user_date_idx
on public.body_metrics(user_id, date);

alter table public.body_metrics enable row level security;

create policy "Users can view their own metrics"
  on public.body_metrics for select
  using ((select auth.uid()) = user_id);

create policy "Users can insert their own metrics"
  on public.body_metrics for insert
  with check ((select auth.uid()) = user_id);

create policy "Users can update their own metrics"
  on public.body_metrics for update
  using ((select auth.uid()) = user_id);

-- ─────────────────────────────────────────────────────────────
-- 3. meal_records  (all diet records: AI-analysed + manual)
-- ─────────────────────────────────────────────────────────────
create table if not exists public.meal_records (
  -- identity
  id              text          primary key,           -- client or server generated UUID
  user_id         uuid          not null references auth.users (id) on delete cascade,
  meal_date       date          not null,              -- YYYY-MM-DD

  -- input
  image_path      text,                               -- Supabase Storage object path (private bucket)
  image_url       text,                               -- signed URL snapshot for convenient rendering

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
if not exists meal_records_user_meal_date_idx
  on public.meal_records
(user_id, meal_date);

-- Supports fetchMeals ORDER BY created_at DESC
create index
if not exists meal_records_user_created_idx
  on public.meal_records
(user_id, created_at desc);

alter table public.meal_records enable row level security;

create policy "Users can view their own meal records"
  on public.meal_records for select
  using ((select auth.uid()) = user_id);

create policy "Users can insert their own meal records"
  on public.meal_records for insert
  with check ((select auth.uid()) = user_id);

create policy "Users can update their own meal records"
  on public.meal_records for update
  using ((select auth.uid()) = user_id);

create policy "Users can delete their own meal records"
  on public.meal_records for delete
  using ((select auth.uid()) = user_id);

-- ─────────────────────────────────────────────────────────────
-- 4. ai_meal_analyses (AI result + user feedback loop)
-- ─────────────────────────────────────────────────────────────
create table if not exists public.ai_meal_analyses (
  id                    uuid          primary key default gen_random_uuid(),
  user_id               uuid          not null references auth.users(id) on delete cascade,
  meal_date             date          not null,
  image_path            text,
  image_url             text,
  ai_summary_name       text,
  ai_items              jsonb         not null default '[]',
  ai_total_calories     integer       not null default 0,
  ai_total_protein      integer       not null default 0,
  ai_total_carbs        integer       not null default 0,
  ai_total_fat          integer       not null default 0,
  ai_total_sugar        integer       not null default 0,
  ai_model              text          not null ,
  input_tokens          integer,
  output_tokens         integer,
  total_tokens          integer,
  image_bytes           integer       not null default 0,
  latency_ms            integer,
  meal_record_id        text          references public.meal_records(id) on delete set null,
  is_correct            boolean,
  confirmed_at          timestamptz,
  feedback_status       text          not null default 'pending' check (
    feedback_status in ('pending', 'confirmed', 'confirmed_with_edit', 'discarded')
  ),
  created_at            timestamptz   not null default now(),
  updated_at            timestamptz   not null default now()
);

create index
if not exists ai_meal_analyses_user_meal_date_idx
  on public.ai_meal_analyses(user_id, meal_date);

create index
if not exists ai_meal_analyses_feedback_status_idx
  on public.ai_meal_analyses(user_id, feedback_status);

create index
if not exists ai_meal_analyses_meal_record_id_idx
  on public.ai_meal_analyses(meal_record_id);

alter table public.ai_meal_analyses enable row level security;
-- No direct client policies on this table.
-- Access is mediated by edge functions using service role.

create policy "Service role can manage ai meal analyses"
  on public.ai_meal_analyses
  for all
  to service_role
  using (true)
  with check (true);

-- ─────────────────────────────────────────────────────────────
-- 5. Storage bucket (meal photo uploads)
-- ─────────────────────────────────────────────────────────────
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'meal-images',
  'meal-images',
  false,
  1500000,
  array['image/jpeg', 'image/png', 'image/webp', 'image/heic', 'image/heif']
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Users can view their own meal images" on storage.objects;
create policy "Users can view their own meal images"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'meal-images'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists "Users can upload their own meal images" on storage.objects;
create policy "Users can upload their own meal images"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'meal-images'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists "Users can update their own meal images" on storage.objects;
create policy "Users can update their own meal images"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'meal-images'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  )
  with check (
    bucket_id = 'meal-images'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists "Users can delete their own meal images" on storage.objects;
create policy "Users can delete their own meal images"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'meal-images'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

-- ─────────────────────────────────────────────────────────────
-- 6. quick_add_items  (用戶自訂快捷食物)
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
  using ((select auth.uid()) = user_id);

create policy "Users can insert their own quick add items"
  on public.quick_add_items for insert
  with check ((select auth.uid()) = user_id);

create policy "Users can update their own quick add items"
  on public.quick_add_items for update
  using ((select auth.uid()) = user_id);

create policy "Users can delete their own quick add items"
  on public.quick_add_items for delete
  using ((select auth.uid()) = user_id);

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
-- 7. Helper: auto-update updated_at
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

create or replace trigger on_ai_meal_analyses_updated
  before update on public.ai_meal_analyses
  for each row
  execute procedure public.handle_updated_at();
