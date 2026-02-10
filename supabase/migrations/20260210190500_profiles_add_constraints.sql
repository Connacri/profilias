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
