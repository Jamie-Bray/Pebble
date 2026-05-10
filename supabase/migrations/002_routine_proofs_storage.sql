insert into storage.buckets (id, name, public)
values ('routine-proofs', 'routine-proofs', false)
on conflict (id) do nothing;

drop policy if exists "routine proofs own read" on storage.objects;
create policy "routine proofs own read" on storage.objects
for select using (
  bucket_id = 'routine-proofs'
  and (storage.foldername(name))[1] = 'users'
  and (storage.foldername(name))[2] = auth.uid()::text
);

drop policy if exists "routine proofs own write" on storage.objects;
create policy "routine proofs own write" on storage.objects
for insert with check (
  bucket_id = 'routine-proofs'
  and (storage.foldername(name))[1] = 'users'
  and (storage.foldername(name))[2] = auth.uid()::text
);

drop policy if exists "routine proofs own update" on storage.objects;
create policy "routine proofs own update" on storage.objects
for update using (
  bucket_id = 'routine-proofs'
  and (storage.foldername(name))[1] = 'users'
  and (storage.foldername(name))[2] = auth.uid()::text
);

drop policy if exists "routine proofs own delete" on storage.objects;
create policy "routine proofs own delete" on storage.objects
for delete using (
  bucket_id = 'routine-proofs'
  and (storage.foldername(name))[1] = 'users'
  and (storage.foldername(name))[2] = auth.uid()::text
);
