-- Station profile photos: column + public bucket; only the station owner may write under <station_id>/...
alter table public.stations add column if not exists photo_url text;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('station-photos', 'station-photos', true, 5242880, array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set public = true, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "station photos insert by owner" on storage.objects;
drop policy if exists "station photos update by owner" on storage.objects;
drop policy if exists "station photos delete by owner" on storage.objects;
create policy "station photos insert by owner" on storage.objects for insert to authenticated
  with check (bucket_id = 'station-photos' and public.owns_station_folder(name));
create policy "station photos update by owner" on storage.objects for update to authenticated
  using (bucket_id = 'station-photos' and public.owns_station_folder(name))
  with check (bucket_id = 'station-photos' and public.owns_station_folder(name));
create policy "station photos delete by owner" on storage.objects for delete to authenticated
  using (bucket_id = 'station-photos' and public.owns_station_folder(name));
