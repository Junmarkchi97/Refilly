-- Security follow-up: distance helper must never be callable anonymously.
-- Rider bearer-token RPCs are intentionally anonymous, but are validated by
-- server-side expiring tokens; review them separately when hardening riders.
revoke all on function public.delivery_distance_km(
  uuid,double precision,double precision
) from public, anon;
grant execute on function public.delivery_distance_km(
  uuid,double precision,double precision
) to authenticated;

-- Keep foreign key maintenance efficient as the routine history grows.
create index if not exists refill_routines_source_order_idx
  on public.refill_routines(source_order_id);
create index if not exists refill_routines_station_idx
  on public.refill_routines(station_id);
create index if not exists user_notifications_order_idx
  on public.user_notifications(order_id);
