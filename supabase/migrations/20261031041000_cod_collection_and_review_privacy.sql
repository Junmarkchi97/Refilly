-- Privacy and cash-on-delivery reconciliation for water-station orders.
-- Existing owner status RPC intentionally never marks COD as paid.
revoke select on public.station_reviews from anon, authenticated;
grant select(station_id,rating,comment,created_at) on public.station_reviews to anon,authenticated;

create or replace function public.confirm_cod_collection(p_order uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare v public.orders%rowtype;
begin
  if auth.uid() is null then raise exception 'authentication required'; end if;
  select * into v from public.orders where id = p_order for update;
  if not found or not public.owns_station(v.station_id) then raise exception 'order not found or access denied'; end if;
  if v.payment_method <> 'cod' or v.status <> 'delivered' or v.payment_status <> 'unpaid'
  then raise exception 'only delivered unpaid COD orders may be confirmed'; end if;
  update public.orders set payment_status='paid', payment_ref='cod-confirmed:' || auth.uid()::text
    where id=p_order;
end $$;
revoke all on function public.confirm_cod_collection(uuid) from public,anon;
grant execute on function public.confirm_cod_collection(uuid) to authenticated;
