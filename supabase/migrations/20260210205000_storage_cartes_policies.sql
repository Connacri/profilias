create policy "Cartes objects are viewable by owner"
on storage.objects for select
using (
  bucket_id = 'cartes'
  and (storage.foldername(name))[1] = 'users'
  and (storage.foldername(name))[2] = auth.uid()::text
);

create policy "Cartes objects are insertable by owner"
on storage.objects for insert
with check (
  bucket_id = 'cartes'
  and (storage.foldername(name))[1] = 'users'
  and (storage.foldername(name))[2] = auth.uid()::text
);

create policy "Cartes objects are deletable by owner"
on storage.objects for delete
using (
  bucket_id = 'cartes'
  and (storage.foldername(name))[1] = 'users'
  and (storage.foldername(name))[2] = auth.uid()::text
);
