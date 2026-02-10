create policy "Cartes are deletable by owner"
on public.cartes for delete
using (auth.uid() = user_id);
