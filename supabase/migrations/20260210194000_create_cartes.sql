create table if not exists public.cartes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  type text not null,
  raw_text text,
  image_path text,
  cni_numero text,
  cni_date_delivrance date,
  cni_lieu_delivrance text,
  cni_date_expiration date,
  cni_nom_prenom text,
  cni_sexe text,
  cni_date_lieu_naissance text,
  cni_nin text,
  chifa_immatriculation text,
  chifa_nom_prenom text,
  chifa_date_naissance date,
  chifa_type_carte text,
  chifa_numero_serie text,
  ccp_nom_prenom text,
  ccp_compte text,
  ccp_cle text,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now()
);

alter table public.cartes enable row level security;

create policy "Cartes are viewable by owner"
on public.cartes for select
using (auth.uid() = user_id);

create policy "Cartes are insertable by owner"
on public.cartes for insert
with check (auth.uid() = user_id);

create policy "Cartes are updatable by owner"
on public.cartes for update
using (auth.uid() = user_id);

create policy "Cartes are deletable by owner"
on public.cartes for delete
using (auth.uid() = user_id);

create or replace function public.handle_cartes_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists set_cartes_updated_at on public.cartes;
create trigger set_cartes_updated_at
before update on public.cartes
for each row execute function public.handle_cartes_updated_at();
