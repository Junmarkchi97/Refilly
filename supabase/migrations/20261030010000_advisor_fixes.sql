-- Advisor fixes: lock down SECURITY DEFINER functions, pin search_path, index FKs.
alter function public.touch_updated_at() set search_path = public;
revoke execute on function public.handle_new_user() from public, anon, authenticated;
revoke execute on function public.my_role() from public, anon;
revoke execute on function public.owns_station(uuid) from public, anon;
revoke execute on function public.place_order(uuid, jsonb, text, double precision, double precision, text, text, public.payment_method) from public, anon;
revoke execute on function public.station_sales(uuid, timestamptz, timestamptz) from public, anon;
revoke execute on function public.station_top_products(uuid, timestamptz, timestamptz) from public, anon;
create index if not exists order_items_order_id_idx on public.order_items(order_id);
create index if not exists order_items_product_id_idx on public.order_items(product_id);
create index if not exists products_category_id_idx on public.products(category_id);
create index if not exists profiles_station_id_idx on public.profiles(station_id);
create index if not exists rider_locations_order_id_idx on public.rider_locations(order_id);
create index if not exists stations_owner_id_idx on public.stations(owner_id);
