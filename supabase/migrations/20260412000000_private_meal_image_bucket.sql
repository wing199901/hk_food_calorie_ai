-- Make meal image storage private and persist object paths for signed URL access.

alter table public.meal_records
  add column if not exists image_path text;

-- Best-effort backfill for legacy public URLs so existing records remain viewable.
update public.meal_records
set image_path = regexp_replace(
  image_url,
  '^https?://[^/]+/storage/v1/object/public/meal-images/',
  ''
)
where image_path is null
  and image_url is not null
  and image_url ~ '^https?://[^/]+/storage/v1/object/public/meal-images/.+';

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
