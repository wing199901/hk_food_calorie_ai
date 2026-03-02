-- ============================================================
-- FitCalorie – Supabase Database Schema
-- Run this SQL in: Supabase Dashboard → SQL Editor → New Query
-- ============================================================

-- Enable Row Level Security (RLS) helpers
-- Each table is scoped to the authenticated user via user_id = auth.uid()

-- ─────────────────────────────────────────────────────────────
-- 1. user_profiles
-- ─────────────────────────────────────────────────────────────
create table if not exists public.user_profiles (
  user_id           uuid primary key references auth.users(id) on delete cascade,
  age               integer,
  weight            numeric(5,2),
  height            numeric(5,2),
  waistline         numeric(5,2),
  gender            text,          -- 'male' | 'female' | 'other'
  activity_level    text,          -- 'sedentary' | 'light' | 'moderate' | 'active' | 'very-active'
  calorie_target    integer default 2000,
  last_check_in_date date,         -- date type (YYYY-MM-DD)
  created_at        timestamptz default now(),
  updated_at        timestamptz default now()
);

alter table public.user_profiles enable row level security;

create policy "Users can view their own profile"
  on public.user_profiles for select
  using (auth.uid() = user_id);

create policy "Users can insert their own profile"
  on public.user_profiles for insert
  with check (auth.uid() = user_id);

create policy "Users can update their own profile"
  on public.user_profiles for update
  using (auth.uid() = user_id);

-- ─────────────────────────────────────────────────────────────
-- 2. body_metrics
-- ─────────────────────────────────────────────────────────────
create table if not exists public.body_metrics (
  user_id    uuid not null references auth.users(id) on delete cascade,
  date       date not null,                   -- date type (YYYY-MM-DD)
  weight     numeric(5,2),
  waistline  numeric(5,2),
  created_at timestamptz default now(),
  primary key (user_id, date)
);

alter table public.body_metrics enable row level security;

create policy "Users can view their own metrics"
  on public.body_metrics for select
  using (auth.uid() = user_id);

create policy "Users can insert their own metrics"
  on public.body_metrics for insert
  with check (auth.uid() = user_id);

create policy "Users can update their own metrics"
  on public.body_metrics for update
  using (auth.uid() = user_id);

-- ─────────────────────────────────────────────────────────────
-- 3. meal_records  (所有飲食紀錄：AI 分析 + 手動輸入)
-- ─────────────────────────────────────────────────────────────
create table if not exists public.meal_records (
  id              text primary key,               -- client or server generated
  user_id         uuid not null references auth.users(id) on delete cascade,
  date            date not null,                -- date type (YYYY-MM-DD)
  items           jsonb not null default '[]',  -- AI 解析的食物陣列
  total_calories  integer not null default 0,
  total_protein   integer default 0,
  total_carbs     integer default 0,
  total_fat       integer default 0,
  image_url       text,                         -- 原始相片 URL / base64 ref
  deleted_at      timestamptz,                  -- soft delete
  created_at      timestamptz default now(),
  updated_at      timestamptz default now()
);

-- items jsonb 內每個元素格式：
-- {
--   "name":       "叉燒飯",
--   "name_en":    "Char Siu Rice",
--   "calories":   650,
--   "protein":    35,
--   "carbs":      80,
--   "fat":        20,
--   "portion":    "1碟",
--   "confidence": 0.92
-- }

create index if not exists meal_records_user_date_idx
  on public.meal_records (user_id, date);

alter table public.meal_records enable row level security;

create policy "Users can view their own meal records"
  on public.meal_records for select
  using (auth.uid() = user_id);

create policy "Users can insert their own meal records"
  on public.meal_records for insert
  with check (auth.uid() = user_id);

create policy "Users can update their own meal records"
  on public.meal_records for update
  using (auth.uid() = user_id);

create policy "Users can delete their own meal records"
  on public.meal_records for delete
  using (auth.uid() = user_id);

-- ─────────────────────────────────────────────────────────────
-- 4. hk_foods  (香港食物資料庫 – V2 用)
-- ─────────────────────────────────────────────────────────────
create table if not exists public.hk_foods (
  id              serial primary key,
  name            text not null,                -- 中文名
  name_en         text,                         -- 英文名
  calories_per_100g  integer,
  protein_per_100g   numeric(5,1),
  carbs_per_100g     numeric(5,1),
  fat_per_100g       numeric(5,1),
  typical_portion    text,                      -- e.g. '1碗 (250g)'
  typical_calories   integer,                   -- 常見份量的卡路里
  category        text,                         -- '茶餐廳' | '粥粉麵飯' | '甜品' | ...
  created_at      timestamptz default now()
);

-- full-text / trigram search (需要 pg_trgm extension)
-- Supabase 已預裝 pg_trgm，可直接用
create extension if not exists pg_trgm;
create index if not exists hk_foods_name_trgm_idx
  on public.hk_foods using gin (name gin_trgm_ops);
create index if not exists hk_foods_name_en_trgm_idx
  on public.hk_foods using gin (name_en gin_trgm_ops);

-- hk_foods 是公開唯讀，不需要 RLS 限制寫入（admin only via service role）
alter table public.hk_foods enable row level security;
create policy "Anyone can read hk_foods"
  on public.hk_foods for select
  using (true);

-- ─────────────────────────────────────────────────────────────
-- 5. Helper: auto-update updated_at
-- ─────────────────────────────────────────────────────────────
create or replace function public.handle_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace trigger on_user_profiles_updated
  before update on public.user_profiles
  for each row execute procedure public.handle_updated_at();

create or replace trigger on_meal_records_updated
  before update on public.meal_records
  for each row execute procedure public.handle_updated_at();
