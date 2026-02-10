alter table public.profiles
  add column if not exists cni_auto_update_opt_out boolean not null default false;
