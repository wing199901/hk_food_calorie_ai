-- Add AI meal analysis feedback loop table.

create extension if not exists pgcrypto;

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
  ai_model              text          not null,
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

create index if not exists ai_meal_analyses_user_meal_date_idx
  on public.ai_meal_analyses(user_id, meal_date);

create index if not exists ai_meal_analyses_feedback_status_idx
  on public.ai_meal_analyses(user_id, feedback_status);

create index if not exists ai_meal_analyses_meal_record_id_idx
  on public.ai_meal_analyses(meal_record_id);

alter table public.ai_meal_analyses enable row level security;

drop policy if exists "Users can view their own ai meal analyses" on public.ai_meal_analyses;
drop policy if exists "Users can insert their own ai meal analyses" on public.ai_meal_analyses;
drop policy if exists "Users can update their own ai meal analyses" on public.ai_meal_analyses;
drop policy if exists "Users can delete their own ai meal analyses" on public.ai_meal_analyses;
-- No direct user policies for this table.
-- Read/write is restricted to edge functions using service role.

drop policy if exists "Service role can manage ai meal analyses" on public.ai_meal_analyses;
create policy "Service role can manage ai meal analyses"
  on public.ai_meal_analyses
  for all
  to service_role
  using (true)
  with check (true);

drop trigger if exists on_ai_meal_analyses_updated on public.ai_meal_analyses;
create trigger on_ai_meal_analyses_updated
  before update on public.ai_meal_analyses
  for each row
  execute procedure public.handle_updated_at();
