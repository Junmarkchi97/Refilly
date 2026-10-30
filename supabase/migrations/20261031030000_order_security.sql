-- Security hardening: all order changes must pass through narrow, validated RPCs.
-- This migration must be applied before deploying the matching Flutter client.
revoke update on public.orders from authenticated, anon;

create or replace function public.owner_set_order_status(p_order uuid, p_status public.order_status)
returns void language plpgsql security definer set search_path = '' as $$
declare v public.orders%rowtype;
begin
  if (select auth.uid()) is null then raise exception 'authentication required'; end if;
  select * into v from public.orders where id = p_order for update;
  if not found or not public.owns_station(v.station_id) then
    raise exception 'order not found or access denied';
  end if;
  if not (
    (v.status = 'pending' and p_status in ('accepted', 'cancelled'))
    or (v.status = 'accepted' and p_status = 'preparing')
    or (v.status = 'preparing' and p_status = 'cancelled')
    or (v.status = 'out_for_delivery' and p_status = 'delivered')
  ) then raise exception 'invalid order status transition'; end if;
  update public.orders set status = p_status where id = p_order;
end $$;
revoke all on function public.owner_set_order_status(uuid, public.order_status) from public, anon;
grant execute on function public.owner_set_order_status(uuid, public.order_status) to authenticated;

-- Recreate the rider transition function without automatically treating delivery as payment.
create or replace function public.rider_set_status(p_token text, p_status public.order_status)
returns void language plpgsql security definer set search_path = '' as $$
declare oid uuid := public._rider_order(p_token);
begin
  if oid is null then raise exception 'link expired or invalid'; end if;
  if p_status = 'out_for_delivery' then
    update public.orders set status = p_status
      where id = oid and status in ('accepted','preparing','out_for_delivery');
  elsif p_status = 'delivered' then
    update public.orders set status = p_status
      where id = oid and status = 'out_for_delivery';
  else raise exception 'riders can only set out_for_delivery or delivered'; end if;
  if not found then raise exception 'invalid status change'; end if;
  if p_status = 'delivered' then
    update public.order_rider_links set expires_at = now() where order_id = oid;
  end if;
end $$;
revoke all on function public.rider_set_status(text, public.order_status) from public;
grant execute on function public.rider_set_status(text, public.order_status) to anon, authenticated;

-- Do not issue rider links for pending or already dispatched orders; require contact details.
create or replace function public.assign_rider(p_order uuid, p_name text, p_phone text)
returns text language plpgsql security definer set search_path = '' as $$
declare t text := replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', '');
begin
  if nullif(trim(coalesce(p_name,'')), '') is null
    or trim(coalesce(p_phone,'')) !~ '^(\\+?63|0)9[0-9]{9}$'
  then raise exception 'valid rider name and Philippine mobile number required'; end if;
  update public.orders set rider_name = trim(p_name), rider_phone = trim(p_phone)
    where id = p_order and public.owns_station(station_id) and status in ('accepted','preparing');
  if not found then raise exception 'order not assignable'; end if;
  insert into public.order_rider_links(order_id, token) values (p_order, t)
    on conflict (order_id) do update set token = excluded.token,
      expires_at = now() + interval '48 hours', created_at = now();
  return t;
end $$;
revoke all on function public.assign_rider(uuid,text,text) from public, anon;
grant execute on function public.assign_rider(uuid,text,text) to authenticated;

-- Validate drop-off coordinates together, and require a delivery point.
create or replace function public.place_order(
  p_station uuid, p_items jsonb, p_address text, p_lat double precision,
  p_lng double precision, p_phone text, p_notes text,
  p_payment public.payment_method default 'cod'
) returns uuid language plpgsql security definer set search_path = '' as $$
declare oid uuid; it jsonb; pr public.products%rowtype; tot numeric := 0;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if p_payment <> 'cod' then raise exception 'online payments are not enabled'; end if;
  if nullif(trim(coalesce(p_address,'')), '') is null then raise exception 'delivery address required'; end if;
  if p_lat is null or p_lng is null or not (p_lat between -90 and 90)
    or not (p_lng between -180 and 180) then raise exception 'valid delivery pin required'; end if;
  if (select require_phone_verification from public.app_config) and not exists(
    select 1 from auth.users where id = auth.uid() and phone_confirmed_at is not null)
  then raise exception 'phone not verified'; end if;
  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0
    or jsonb_array_length(p_items) > 100 then raise exception 'invalid cart'; end if;
  if not exists (select 1 from public.stations where id = p_station and is_open)
  then raise exception 'station is closed or unavailable'; end if;
  insert into public.orders(customer_id, station_id, delivery_address, delivery_lat, delivery_lng,
    contact_phone, notes, payment_method)
  values (auth.uid(), p_station, trim(p_address), p_lat, p_lng, p_phone, p_notes, p_payment)
  returning id into oid;
  for it in select * from jsonb_array_elements(p_items) loop
    if jsonb_typeof(it) <> 'object'
      or coalesce(it->>'quantity','') !~ '^[0-9]{1,3}$'
      or (it->>'quantity')::int not between 1 and 100
      or coalesce(it->>'product_id','') !~ '^[0-9a-fA-F-]{36}$'
    then raise exception 'invalid cart item'; end if;
    select * into pr from public.products
      where id = (it->>'product_id')::uuid and station_id = p_station and is_available;
    if not found then raise exception 'product unavailable'; end if;
    insert into public.order_items(order_id, product_id, product_name, unit_price, quantity)
      values (oid, pr.id, pr.name, pr.price, (it->>'quantity')::int);
    tot := tot + pr.price * (it->>'quantity')::int;
  end loop;
  update public.orders set total = tot where id = oid;
  return oid;
end $$;
revoke all on function public.place_order(uuid,jsonb,text,double precision,double precision,text,text,public.payment_method) from public, anon;
grant execute on function public.place_order(uuid,jsonb,text,double precision,double precision,text,text,public.payment_method) to authenticated;

-- Prevent a public rider link from returning personal information in an HTTP referrer.
-- Deploy web hosting with Referrer-Policy: no-referrer and Cache-Control: no-store on rider routes.
