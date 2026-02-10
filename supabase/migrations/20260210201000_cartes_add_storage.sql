alter table public.cartes
  add column if not exists image_storage_path text,
  add column if not exists image_url text;
