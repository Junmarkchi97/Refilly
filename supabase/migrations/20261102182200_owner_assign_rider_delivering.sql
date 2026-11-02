-- Saving rider details means the order is already on its way.
-- Accepted and preparing orders move to out_for_delivery. A later edit
-- keeps that status and only refreshes the rider and the private link.
create or replace function public.assign_rider(p_order uuid, p_name text, p_phone text)
returns text language plpgsql security definer set search_path = '' as $$
declare t text := replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', '');
begin
  if nullif(trim(coalesce(p_name,'')), '') is null
    or not (trim(coalesce(p_phone,'')) ~ concat('^([+]63|63|0)9[0-9]{9}', chr(36)))
  then raise exception 'valid rider name and Philippine mobile number required'; end if;
  update public.orders
    set rider_name = trim(p_name),
        rider_phone = trim(p_phone),
        status = case
          when status in ('accepted', 'preparing') then 'out_for_delivery'::public.order_status
          else status
        end
    where id = p_order
      and public.owns_station(station_id)
      and status in ('accepted', 'preparing', 'out_for_delivery');
  if not found then raise exception 'order not assignable'; end if;
  insert into public.order_rider_links(order_id, token) values (p_order, t)
    on conflict (order_id) do update set token = excluded.token,
      expires_at = now() + interval '48 hours', created_at = now();
  return t;
end $$;

revoke all on function public.assign_rider(uuid, text, text) from public, anon;
grant execute on function public.assign_rider(uuid, text, text) to authenticated;

-- Say "delivering" in the customer and owner notification for that status.
create or replace function public.notify_order_status() returns trigger
language plpgsql security definer set search_path = '' as $$
declare owner_user uuid; msg text;
begin
  if tg_op = 'UPDATE' and new.status is not distinct from old.status then return new; end if;
  msg := case new.status
    when 'out_for_delivery' then 'delivering'
    else replace(new.status::text, '_', ' ')
  end;
  insert into public.user_notifications(user_id, order_id, title, body)
  values (new.customer_id, new.id, 'Order update', 'Your water order is now ' || msg || '.');
  select owner_id into owner_user from public.stations where id = new.station_id;
  if owner_user is not null and owner_user <> new.customer_id then
    insert into public.user_notifications(user_id, order_id, title, body)
    values (owner_user, new.id, 'Station order update', 'An order is now ' || msg || '.');
  end if;
  return new;
end $$;

revoke all on function public.notify_order_status() from public, anon, authenticated;
