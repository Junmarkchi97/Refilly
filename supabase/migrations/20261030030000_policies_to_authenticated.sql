-- Scope owner/customer policies to signed-in users so anon gets empty results instead of errors,
-- and wrap auth.uid() for per-statement evaluation.
alter policy "customer orders" on orders to authenticated using (customer_id = (select auth.uid()));
alter policy "owner orders" on orders to authenticated;
alter policy "owner update orders" on orders to authenticated;
alter policy "owner manage products" on products to authenticated;
alter policy "owner update station" on stations to authenticated using (owner_id = (select auth.uid()));
alter policy "owner delete station" on stations to authenticated using (owner_id = (select auth.uid()));

-- Allow re-uploading (upsert) own owner documents
create policy "owner-docs update own" on storage.objects for update to authenticated
  using (bucket_id = 'owner-docs' and (storage.foldername(name))[1] = (select auth.uid())::text)
  with check (bucket_id = 'owner-docs' and (storage.foldername(name))[1] = (select auth.uid())::text);
