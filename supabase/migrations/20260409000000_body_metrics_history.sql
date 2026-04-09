-- Make body_metrics append-only history instead of one row per day.

update public.body_metrics
set created_at = coalesce(created_at, (date::timestamp at time zone 'utc'))
where created_at is null;

alter table public.body_metrics
  alter column created_at set not null;

alter table public.body_metrics
  drop constraint if exists body_metrics_pkey;

alter table public.body_metrics
  add primary key (user_id, date, created_at);

create index if not exists body_metrics_user_date_idx
  on public.body_metrics(user_id, date);
