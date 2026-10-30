-- Product images: column + public bucket; only the station owner may write under <station_id>/...
alter table public.products add column if not exists image_url text;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('product-images', 'product-images', true, 5242880, array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set public = true, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

create or replace function public.owns_station_folder(p_name text)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.stations s
    where s.id::text = (storage.foldername(p_name))[1] and s.owner_id = (select auth.uid())
  );
$$;
revoke all on function public.owns_station_folder(text) from public, anon;
grant execute on function public.owns_station_folder(text) to authenticated;

drop policy if exists "product images insert by owner" on storage.objects;
drop policy if exists "product images update by owner" on storage.objects;
drop policy if exists "product images delete by owner" on storage.objects;
create policy "product images insert by owner" on storage.objects for insert to authenticated
  with check (bucket_id = 'product-images' and public.owns_station_folder(name));
create policy "product images update by owner" on storage.objects for update to authenticated
  using (bucket_id = 'product-images' and public.owns_station_folder(name))
  with check (bucket_id = 'product-images' and public.owns_station_folder(name));
create policy "product images delete by owner" on storage.objects for delete to authenticated
  using (bucket_id = 'product-images' and public.owns_station_folder(name));
