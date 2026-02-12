insert into storage.buckets (id, name, public)
values ('cartes', 'cartes', false)
on conflict (id) do nothing;
