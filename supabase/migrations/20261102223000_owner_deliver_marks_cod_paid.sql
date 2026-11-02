-- Delivering an order means COD cash was collected with the handoff.
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
    (v.status = 'pending' and p_status in ('accepted', 'preparing', 'cancelled'))
    or (v.status = 'accepted' and p_status in ('preparing', 'delivered', 'cancelled'))
    or (v.status = 'preparing' and p_status in ('cancelled', 'delivered'))
    or (v.status = 'out_for_delivery' and p_status = 'delivered')
  ) then raise exception 'invalid order status transition'; end if;
  update public.orders
    set status = p_status,
        payment_status = case
          when p_status = 'delivered' and v.payment_method = 'cod' then 'paid'::public.payment_status
          else v.payment_status
        end,
        payment_ref = case
          when p_status = 'delivered' and v.payment_method = 'cod' and v.payment_status = 'unpaid'
            then 'cod-delivered:' || (select auth.uid())::text
          else v.payment_ref
        end
  where id = p_order;
end $$;

revoke all on function public.owner_set_order_status(uuid, public.order_status) from public, anon;
grant execute on function public.owner_set_order_status(uuid, public.order_status) to authenticated;
