-- Owners need SELECT on their station-photo objects for upsert/existence checks.
-- Public read keeps getPublicUrl working for customers even when RLS is tight.
drop policy if exists "station photos select by owner" on storage.objects;
drop policy if exists "station photos public read" on storage.objects;
create policy "station photos public read" on storage.objects for select to anon, authenticated
  using (bucket_id = 'station-photos');

drop policy if exists "product images public read" on storage.objects;
create policy "product images public read" on storage.objects for select to anon, authenticated
  using (bucket_id = 'product-images');
