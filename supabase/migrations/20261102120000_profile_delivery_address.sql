-- Saved customer delivery address for Profile settings + checkout autofill.
alter table public.profiles
  add column if not exists delivery_address text,
  add column if not exists delivery_lat double precision,
  add column if not exists delivery_lng double precision;

-- Column-level grants stay narrow: role stays immutable; name/phone/address are editable.
grant update (full_name, phone, delivery_address, delivery_lat, delivery_lng)
  on public.profiles to authenticated;
