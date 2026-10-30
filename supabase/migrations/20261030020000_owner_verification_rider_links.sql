-- Riders no longer have accounts; owners are verified by an admin; phone OTP gate.

-- 1) Drop rider-related and role-dependent policies
drop policy if exists "rider orders" on orders;
drop policy if exists "rider update orders" on orders;
drop policy if exists "customer cancel pending" on orders;
drop policy if exists "items visible with order" on order_items;
drop policy if exists "rider writes own location" on rider_locations;
drop policy if exists "customer/owner see rider location" on rider_locations;
drop policy if exists "rider sees customer of assigned order" on profiles;
drop policy if exists "owner assigns riders" on profiles;
drop policy if exists "owner sees unassigned riders" on profiles;
drop policy if exists "owner sees customers/riders of station" on profiles;
drop policy if exists "update own profile" on profiles;
drop policy if exists "own profile" on profiles;
drop policy if exists "owner insert station" on stations;

-- 2) Remove rider accounts and rider columns
alter table orders drop column if exists rider_id;
alter table profiles drop column if exists station_id;
alter publication supabase_realtime drop table rider_locations;
delete from auth.users where id in (select id from profiles where role = 'rider');
drop table rider_locations;

-- 3) Roles: customer | owner | admin
alter table profiles alter column role drop default;
drop function if exists my_role();
alter type user_role rename to user_role_old;
create type user_role as enum ('customer','owner','admin');
alter table profiles alter column role type user_role using (case when role::text = 'rider' then 'customer' else role::text end)::user_role;
alter table profiles alter column role set default 'customer';
drop type user_role_old;

create function my_role() returns user_role language sql stable security definer set search_path = public as
$$ select role from profiles where id = auth.uid() $$;
revoke execute on function my_role() from public, anon;
grant execute on function my_role() to authenticated;

-- Signup always creates a customer; metadata role is ignored.
create or replace function handle_new_user() returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into profiles(id, full_name, phone, role)
  values (new.id, new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'phone', 'customer');
  return new;
end $$;
revoke execute on function handle_new_user() from public, anon, authenticated;

-- Profiles: users can edit only name/phone (never role)
revoke update on profiles from anon, authenticated;
grant update (full_name, phone) on profiles to authenticated;
create policy "profiles select" on profiles for select to authenticated using (
  id = (select auth.uid())
  or exists(select 1 from orders o where o.customer_id = profiles.id and owns_station(o.station_id))
  or (select my_role()) = 'admin');
create policy "update own profile" on profiles for update to authenticated
  using (id = (select auth.uid())) with check (id = (select auth.uid()));

-- 4) Orders: rider info (no account) + secret delivery link
alter table orders add column rider_name text, add column rider_phone text;
create table order_rider_links (
  order_id uuid primary key references orders(id) on delete cascade,
  token text not null unique,
  expires_at timestamptz not null default now() + interval '48 hours',
  created_at timestamptz not null default now()
);
alter table order_rider_links enable row level security;
create policy "owner reads links" on order_rider_links for select to authenticated using (
  exists(select 1 from orders o where o.id = order_id and owns_station(o.station_id)));

create table rider_locations (
  order_id uuid primary key references orders(id) on delete cascade,
  lat double precision not null,
  lng double precision not null,
  heading double precision,
  updated_at timestamptz not null default now()
);
alter table rider_locations enable row level security;
create policy "customer/owner see rider location" on rider_locations for select to authenticated using (
  exists(select 1 from orders o where o.id = rider_locations.order_id and o.status = 'out_for_delivery'
    and (o.customer_id = (select auth.uid()) or owns_station(o.station_id))));
alter publication supabase_realtime add table rider_locations;

create policy "items visible with order" on order_items for select to authenticated using (
  exists(select 1 from orders o where o.id = order_id and (o.customer_id = (select auth.uid()) or owns_station(o.station_id))));

-- Customers cancel via RPC only (the old update policy let them edit other columns)
create or replace function cancel_order(p_order uuid) returns void language plpgsql security definer set search_path = public as $$
begin
  update orders set status = 'cancelled' where id = p_order and customer_id = auth.uid() and status = 'pending';
  if not found then raise exception 'order cannot be cancelled'; end if;
end $$;

-- Owner sets rider name/phone and gets a fresh link token
create or replace function assign_rider(p_order uuid, p_name text, p_phone text) returns text
language plpgsql security definer set search_path = public as $$
declare t text := replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', '');
begin
  update orders set rider_name = nullif(trim(p_name), ''), rider_phone = nullif(trim(p_phone), '')
   where id = p_order and owns_station(station_id) and status not in ('delivered','cancelled');
  if not found then raise exception 'order not found or closed'; end if;
  insert into order_rider_links(order_id, token) values (p_order, t)
    on conflict (order_id) do update set token = excluded.token, expires_at = now() + interval '48 hours', created_at = now();
  return t;
end $$;

-- Internal: resolve a valid token to an order id
create or replace function _rider_order(p_token text) returns uuid language sql stable security definer set search_path = public as $$
  select l.order_id from order_rider_links l join orders o on o.id = l.order_id
  where l.token = p_token and l.expires_at > now() and o.status not in ('delivered','cancelled') $$;
revoke execute on function _rider_order(text) from public, anon, authenticated;

create or replace function rider_get_order(p_token text) returns jsonb language plpgsql stable security definer set search_path = public as $$
declare oid uuid := _rider_order(p_token); r jsonb;
begin
  if oid is null then raise exception 'link expired or invalid'; end if;
  select jsonb_build_object('id', o.id, 'status', o.status, 'total', o.total, 'payment_method', o.payment_method,
      'delivery_address', o.delivery_address, 'delivery_lat', o.delivery_lat, 'delivery_lng', o.delivery_lng,
      'contact_phone', coalesce(o.contact_phone, p.phone), 'notes', o.notes, 'customer_name', p.full_name,
      'rider_name', o.rider_name,
      'station', jsonb_build_object('name', s.name, 'lat', s.lat, 'lng', s.lng, 'phone', s.phone),
      'items', (select coalesce(jsonb_agg(jsonb_build_object('product_name', i.product_name, 'quantity', i.quantity)), '[]') from order_items i where i.order_id = o.id))
    into r from orders o join stations s on s.id = o.station_id left join profiles p on p.id = o.customer_id where o.id = oid;
  return r;
end $$;

create or replace function rider_update_location(p_token text, p_lat double precision, p_lng double precision, p_heading double precision default null)
returns void language plpgsql security definer set search_path = public as $$
declare oid uuid := _rider_order(p_token);
begin
  if oid is null then raise exception 'link expired or invalid'; end if;
  if p_lat not between -90 and 90 or p_lng not between -180 and 180 then raise exception 'bad coordinates'; end if;
  insert into rider_locations(order_id, lat, lng, heading, updated_at) values (oid, p_lat, p_lng, p_heading, now())
    on conflict (order_id) do update set lat = excluded.lat, lng = excluded.lng, heading = excluded.heading, updated_at = now();
end $$;

create or replace function rider_set_status(p_token text, p_status order_status) returns void
language plpgsql security definer set search_path = public as $$
declare oid uuid := _rider_order(p_token);
begin
  if oid is null then raise exception 'link expired or invalid'; end if;
  if p_status = 'out_for_delivery' then
    update orders set status = p_status where id = oid and status in ('accepted','preparing','out_for_delivery');
  elsif p_status = 'delivered' then
    update orders set status = p_status, payment_status = case when payment_method = 'cod' then 'paid' else payment_status end
     where id = oid and status = 'out_for_delivery';
  else raise exception 'riders can only set out_for_delivery or delivered'; end if;
  if not found then raise exception 'invalid status change'; end if;
  if p_status = 'delivered' then update order_rider_links set expires_at = now() where order_id = oid; end if;
end $$;

-- Expire the link whenever an order closes (owner marks delivered/cancelled too)
create or replace function expire_rider_link() returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.status in ('delivered','cancelled') then update order_rider_links set expires_at = least(expires_at, now()) where order_id = new.id; end if;
  return new;
end $$;
revoke execute on function expire_rider_link() from public, anon, authenticated;
create trigger orders_expire_link after update of status on orders for each row execute function expire_rider_link();

-- 5) Phone verification gate (flag lets testing proceed before an SMS provider exists)
create table app_config (
  id boolean primary key default true check (id),
  require_phone_verification boolean not null default false
);
insert into app_config default values;
alter table app_config enable row level security;
create policy "config public" on app_config for select using (true);

create or replace function place_order(p_station uuid, p_items jsonb, p_address text, p_lat double precision,
  p_lng double precision, p_phone text, p_notes text, p_payment payment_method default 'cod')
returns uuid language plpgsql security definer set search_path = public as $$
declare oid uuid; it jsonb; pr products%rowtype; tot numeric := 0;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if (select require_phone_verification from app_config) and not exists(
      select 1 from auth.users where id = auth.uid() and phone_confirmed_at is not null) then
    raise exception 'phone not verified';
  end if;
  if jsonb_array_length(coalesce(p_items, '[]')) = 0 then raise exception 'empty cart'; end if;
  insert into orders(customer_id, station_id, delivery_address, delivery_lat, delivery_lng, contact_phone, notes, payment_method)
  values (auth.uid(), p_station, p_address, p_lat, p_lng, p_phone, p_notes, p_payment) returning id into oid;
  for it in select * from jsonb_array_elements(p_items) loop
    select * into pr from products where id = (it->>'product_id')::uuid and station_id = p_station and is_available;
    if not found then raise exception 'product unavailable'; end if;
    if (it->>'quantity')::int not between 1 and 100 then raise exception 'bad quantity'; end if;
    insert into order_items(order_id, product_id, product_name, unit_price, quantity)
    values (oid, pr.id, pr.name, pr.price, (it->>'quantity')::int);
    tot := tot + pr.price * (it->>'quantity')::int;
  end loop;
  update orders set total = tot where id = oid;
  return oid;
end $$;

-- 6) Owner applications (verified by an admin)
create type application_status as enum ('pending','approved','rejected');
create table owner_applications (
  id uuid primary key default gen_random_uuid(),
  applicant_id uuid not null references profiles(id) on delete cascade,
  business_name text not null,
  station_name text not null,
  address text not null,
  phone text,
  lat double precision not null,
  lng double precision not null,
  permit_path text not null,  -- DTI/SEC or business permit, in bucket owner-docs
  photo_path text not null,   -- station photo, in bucket owner-docs
  status application_status not null default 'pending',
  notes text,
  reviewed_by uuid references profiles(id),
  reviewed_at timestamptz,
  station_id uuid references stations(id) on delete set null,
  created_at timestamptz not null default now()
);
create index on owner_applications(applicant_id);
create index on owner_applications(reviewed_by);
create index on owner_applications(station_id);
create unique index owner_applications_one_pending on owner_applications(applicant_id) where status = 'pending';
alter table owner_applications enable row level security;
create policy "applications select" on owner_applications for select to authenticated using (
  applicant_id = (select auth.uid()) or (select my_role()) = 'admin');
create policy "customer applies" on owner_applications for insert to authenticated with check (
  applicant_id = (select auth.uid()) and status = 'pending' and reviewed_by is null and station_id is null
  and permit_path like (select auth.uid())::text || '/%' and photo_path like (select auth.uid())::text || '/%');

create or replace function approve_owner_application(p_id uuid, p_notes text default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare a owner_applications%rowtype; sid uuid;
begin
  if my_role() is distinct from 'admin' then raise exception 'admins only'; end if;
  select * into a from owner_applications where id = p_id and status = 'pending' for update;
  if not found then raise exception 'application not pending'; end if;
  insert into stations(owner_id, name, address, phone, lat, lng)
  values (a.applicant_id, a.station_name, a.address, a.phone, a.lat, a.lng) returning id into sid;
  update profiles set role = 'owner' where id = a.applicant_id and role = 'customer';
  update owner_applications set status = 'approved', notes = p_notes, reviewed_by = auth.uid(), reviewed_at = now(), station_id = sid where id = p_id;
  return sid;
end $$;

create or replace function reject_owner_application(p_id uuid, p_notes text default null) returns void
language plpgsql security definer set search_path = public as $$
begin
  if my_role() is distinct from 'admin' then raise exception 'admins only'; end if;
  update owner_applications set status = 'rejected', notes = p_notes, reviewed_by = auth.uid(), reviewed_at = now()
   where id = p_id and status = 'pending';
  if not found then raise exception 'application not pending'; end if;
end $$;

-- Private bucket for permits/photos: <uid>/<file>
insert into storage.buckets(id, name, public, file_size_limit, allowed_mime_types)
values ('owner-docs', 'owner-docs', false, 10485760, array['image/jpeg','image/png','image/webp','application/pdf'])
on conflict (id) do nothing;
create policy "owner-docs upload own" on storage.objects for insert to authenticated with check (
  bucket_id = 'owner-docs' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "owner-docs read own or admin" on storage.objects for select to authenticated using (
  bucket_id = 'owner-docs' and ((storage.foldername(name))[1] = (select auth.uid())::text or (select public.my_role()) = 'admin'));

-- Grants: signed-out access only for the rider-link RPCs
revoke execute on function cancel_order(uuid), assign_rider(uuid, text, text), approve_owner_application(uuid, text),
  reject_owner_application(uuid, text), place_order(uuid, jsonb, text, double precision, double precision, text, text, payment_method)
  from public, anon;
grant execute on function cancel_order(uuid), assign_rider(uuid, text, text), approve_owner_application(uuid, text),
  reject_owner_application(uuid, text), place_order(uuid, jsonb, text, double precision, double precision, text, text, payment_method)
  to authenticated;
revoke execute on function rider_get_order(text), rider_update_location(text, double precision, double precision, double precision),
  rider_set_status(text, order_status) from public;
grant execute on function rider_get_order(text), rider_update_location(text, double precision, double precision, double precision),
  rider_set_status(text, order_status) to anon, authenticated;
