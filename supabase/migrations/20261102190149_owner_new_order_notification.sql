-- A newly placed order tells the station owner immediately.
-- Later status changes keep the shorter update wording.
create or replace function public.notify_order_status() returns trigger
language plpgsql security definer set search_path = '' as $$
declare owner_user uuid; msg text; customer_name text;
begin
  if tg_op = 'UPDATE' and new.status is not distinct from old.status then return new; end if;

  select owner_id into owner_user from public.stations where id = new.station_id;

  if tg_op = 'INSERT' then
    select nullif(trim(full_name), '') into customer_name
      from public.profiles where id = new.customer_id;
    insert into public.user_notifications(user_id, order_id, title, body)
    values (new.customer_id, new.id, 'Order placed', 'The station received your order.');
    if owner_user is not null and owner_user <> new.customer_id then
      insert into public.user_notifications(user_id, order_id, title, body)
      values (
        owner_user,
        new.id,
        'New order',
        coalesce(customer_name, 'A customer') || ' placed an order.'
      );
    end if;
    return new;
  end if;

  msg := case new.status
    when 'out_for_delivery' then 'delivering'
    else replace(new.status::text, '_', ' ')
  end;
  insert into public.user_notifications(user_id, order_id, title, body)
  values (new.customer_id, new.id, 'Order update', 'Your water order is now ' || msg || '.');
  if owner_user is not null and owner_user <> new.customer_id then
    insert into public.user_notifications(user_id, order_id, title, body)
    values (owner_user, new.id, 'Station order update', 'An order is now ' || msg || '.');
  end if;
  return new;
end $$;

revoke all on function public.notify_order_status() from public, anon, authenticated;
