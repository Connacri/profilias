create table if not exists public.profiles (
  id uuid primary key,
  email text,
  full_name text,
  date_of_birth date,
  role text,
  gender text,
  looking_for text,
  bio text,
  gallery jsonb not null default '[]'::jsonb,
  latitude double precision,
  longitude double precision,
  city text,
  country text,
  last_active_at timestamp with time zone not null default now(),
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  photoprofil_url text,
  cover_url text,
  occupation text,
  height_cm integer,
  education text,
  relationship_status text,
  social jsonb not null default '[]'::jsonb,
  cni_auto_update_opt_out boolean not null default false
);

alter table public.profiles
  add constraint profiles_user_fk
  foreign key (id) references auth.users(id) on delete cascade;

create unique index if not exists profiles_email_unique on public.profiles (email);

create or replace function public.handle_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists set_profiles_updated_at on public.profiles;
create trigger set_profiles_updated_at
before update on public.profiles
for each row execute function public.handle_updated_at();

alter table public.profiles enable row level security;

create policy "Profiles are viewable by owner"
on public.profiles for select
using (auth.uid() = id);

create policy "Profiles are insertable by owner"
on public.profiles for insert
with check (auth.uid() = id);

create policy "Profiles are updatable by owner"
on public.profiles for update
using (auth.uid() = id);
