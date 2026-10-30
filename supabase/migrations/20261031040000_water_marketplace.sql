-- Water-station marketplace features: service zones, server-priced fees, reviews, inbox.
-- Apply after 20261031030000_order_security.sql. Back up and test in staging first.
alter table public.stations
  add column if not exists delivery_radius_km numeric(6,2) not null default 10
    check (delivery_radius_km > 0 and delivery_radius_km <= 100),
  add column if not exists delivery_fee numeric(10,2) not null default 0
    check (delivery_fee >= 0 and delivery_fee <= 5000);
alter table public.orders
  add column if not exists delivery_fee numeric(10,2) not null default 0 check (delivery_fee >= 0);

-- Straight-line coverage, not road distance. No routing or rider-location changes.
create or replace function public.delivery_distance_km(p_station uuid, p_lat double precision, p_lng double precision)
returns double precision language sql stable security definer set search_path = '' as $$
  select 6371.0 * acos(greatest(-1.0, least(1.0,
    sin(radians(s.lat))*sin(radians(p_lat))
    + cos(radians(s.lat))*cos(radians(p_lat))*cos(radians(p_lng-s.lng))
  ))) from public.stations s where s.id=p_station
$$;
revoke all on function public.delivery_distance_km(uuid,double precision,double precision) from public;
grant execute on function public.delivery_distance_km(uuid,double precision,double precision) to authenticated;

create or replace function public.delivery_quote(p_station uuid, p_lat double precision, p_lng double precision)
returns numeric language plpgsql stable security definer set search_path = '' as $$
declare s public.stations%rowtype; distance_km double precision;
begin
  if auth.uid() is null then raise exception 'authentication required'; end if;
  if p_lat is null or p_lng is null or not p_lat between -90 and 90 or not p_lng between -180 and 180
  then raise exception 'valid delivery pin required'; end if;
  select * into s from public.stations where id=p_station and is_open;
  if not found then raise exception 'station is closed or unavailable'; end if;
  distance_km := public.delivery_distance_km(p_station,p_lat,p_lng);
  if distance_km > s.delivery_radius_km then raise exception 'outside station delivery area'; end if;
  return s.delivery_fee;
end $$;
revoke all on function public.delivery_quote(uuid,double precision,double precision) from public, anon;
grant execute on function public.delivery_quote(uuid,double precision,double precision) to authenticated;

-- Replace previous placement RPC: totals and serviceability remain authoritative.
create or replace function public.place_order(
  p_station uuid, p_items jsonb, p_address text, p_lat double precision,
  p_lng double precision, p_phone text, p_notes text,
  p_payment public.payment_method default 'cod'
) returns uuid language plpgsql security definer set search_path = '' as $$
declare oid uuid; it jsonb; pr public.products%rowtype; tot numeric := 0; fee numeric;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if p_payment <> 'cod' then raise exception 'online payments are not enabled'; end if;
  if nullif(trim(coalesce(p_address,'')), '') is null then raise exception 'delivery address required'; end if;
  fee := public.delivery_quote(p_station,p_lat,p_lng);
  if (select require_phone_verification from public.app_config) and not exists(
    select 1 from auth.users where id = auth.uid() and phone_confirmed_at is not null)
  then raise exception 'phone not verified'; end if;
  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0
    or jsonb_array_length(p_items) > 100 then raise exception 'invalid cart'; end if;
  insert into public.orders(customer_id,station_id,delivery_address,delivery_lat,delivery_lng,
    contact_phone,notes,payment_method,delivery_fee)
  values(auth.uid(),p_station,trim(p_address),p_lat,p_lng,p_phone,p_notes,p_payment,fee)
  returning id into oid;
  for it in select * from jsonb_array_elements(p_items) loop
    if jsonb_typeof(it) <> 'object'
      or coalesce(it->>'quantity','') !~ '^[0-9]{1,3}$'
      or (it->>'quantity')::int not between 1 and 100
      or coalesce(it->>'product_id','') !~ '^[0-9a-fA-F-]{36}$'
    then raise exception 'invalid cart item'; end if;
    select * into pr from public.products
      where id=(it->>'product_id')::uuid and station_id=p_station and is_available;
    if not found then raise exception 'product unavailable'; end if;
    insert into public.order_items(order_id,product_id,product_name,unit_price,quantity)
      values(oid,pr.id,pr.name,pr.price,(it->>'quantity')::int);
    tot := tot + pr.price * (it->>'quantity')::int;
  end loop;
  update public.orders set total=tot+fee where id=oid;
  return oid;
end $$;
revoke all on function public.place_order(uuid,jsonb,text,double precision,double precision,text,text,public.payment_method) from public,anon;
grant execute on function public.place_order(uuid,jsonb,text,double precision,double precision,text,text,public.payment_method) to authenticated;

-- An order can be reviewed once, by its customer, after delivery.
create table if not exists public.station_reviews(
 id uuid primary key default gen_random_uuid(),
 order_id uuid not null unique references public.orders(id) on delete cascade,
 station_id uuid not null references public.stations(id) on delete cascade,
 customer_id uuid not null references public.profiles(id) on delete cascade,
 rating int not null check(rating between 1 and 5),
 comment text check(char_length(comment)<=1000),
 created_at timestamptz not null default now()
);
create index if not exists station_reviews_station_idx on public.station_reviews(station_id);
alter table public.station_reviews enable row level security;
create policy "reviews public read" on public.station_reviews for select to anon,authenticated using(true);
create policy "customers review delivered orders" on public.station_reviews for insert to authenticated
with check(customer_id=(select auth.uid()) and exists(
 select 1 from public.orders o where o.id=order_id and o.customer_id=customer_id
 and o.station_id=station_id and o.status='delivered'
));
revoke all on public.station_reviews from anon,authenticated;
grant select on public.station_reviews to anon,authenticated;
grant insert(order_id,station_id,customer_id,rating,comment) on public.station_reviews to authenticated;

-- Private in-app notifications for order changes, independent of push-provider configuration.
create table if not exists public.user_notifications(
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references public.profiles(id) on delete cascade,
 order_id uuid references public.orders(id) on delete cascade,
 title text not null,
 body text not null,
 is_read boolean not null default false,
 created_at timestamptz not null default now()
);
create index if not exists user_notifications_user_created on public.user_notifications(user_id,created_at desc);
alter table public.user_notifications enable row level security;
create policy "own notifications read" on public.user_notifications for select to authenticated
using (user_id=(select auth.uid()));
create policy "own notifications mark read" on public.user_notifications for update to authenticated
using (user_id=(select auth.uid())) with check(user_id=(select auth.uid()));
revoke all on public.user_notifications from anon,authenticated;
grant select on public.user_notifications to authenticated;
grant update(is_read) on public.user_notifications to authenticated;

create or replace function public.notify_order_status() returns trigger
language plpgsql security definer set search_path = '' as $$
declare owner_user uuid; msg text;
begin
  if tg_op='UPDATE' and new.status is not distinct from old.status then return new; end if;
  msg := replace(new.status::text,'_',' ');
  insert into public.user_notifications(user_id,order_id,title,body)
  values(new.customer_id,new.id,'Order update','Your water order is now '||msg||'.');
  select owner_id into owner_user from public.stations where id=new.station_id;
  if owner_user is not null and owner_user <> new.customer_id then
    insert into public.user_notifications(user_id,order_id,title,body)
    values(owner_user,new.id,'Station order update','An order is now '||msg||'.');
  end if;
  return new;
end $$;
revoke all on function public.notify_order_status() from public,anon,authenticated;
drop trigger if exists notify_order_status_insert on public.orders;
drop trigger if exists notify_order_status_update on public.orders;
create trigger notify_order_status_insert after insert on public.orders for each row execute function public.notify_order_status();
create trigger notify_order_status_update after update of status on public.orders for each row execute function public.notify_order_status();
