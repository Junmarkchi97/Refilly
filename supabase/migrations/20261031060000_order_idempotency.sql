-- Idempotent checkout: identical retries always return the same order ID.
-- Atomic per (authenticated customer, client-generated request UUID).
-- Preserve the original place_order implementation, but make the idempotent
-- wrapper the ONLY client-accessible checkout endpoint.
create table if not exists public.order_requests (
  customer_id uuid not null references public.profiles(id) on delete cascade,
  request_id uuid not null,
  payload jsonb not null,
  order_id uuid references public.orders(id) on delete restrict,
  created_at timestamptz not null default now(),
  primary key(customer_id, request_id)
);
create index if not exists order_requests_order_id_idx on public.order_requests(order_id);
alter table public.order_requests enable row level security;
revoke all on public.order_requests from public, anon, authenticated;

create or replace function public.place_order_idempotent(
  p_station uuid, p_items jsonb, p_address text,
  p_lat double precision, p_lng double precision, p_phone text,
  p_notes text, p_payment public.payment_method, p_request_id uuid
)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  v_customer uuid := (select auth.uid());
  v_payload jsonb;
  v_record public.order_requests%rowtype;
  v_order uuid;
begin
  if v_customer is null then raise exception 'authentication required'; end if;
  if p_request_id is null then raise exception 'request id required'; end if;
  v_payload := jsonb_build_object(
    'station',p_station,'items',p_items,'address',trim(coalesce(p_address,'')),
    'lat',p_lat,'lng',p_lng,'phone',p_phone,'notes',p_notes,'payment',p_payment
  );
  insert into public.order_requests(customer_id,request_id,payload)
  values(v_customer,p_request_id,v_payload)
  on conflict (customer_id,request_id) do nothing;

  -- This SELECT locks the row, so concurrent retries wait for the first
  -- transaction to commit; failures roll back both the claim and the order.
  select * into v_record from public.order_requests
    where customer_id=v_customer and request_id=p_request_id for update;
  if v_record.payload is distinct from v_payload then
    raise exception 'request identifier already used for different order details';
  end if;
  if v_record.order_id is not null then
    return v_record.order_id;
  end if;

  v_order := public.place_order(
    p_station, p_items, p_address, p_lat, p_lng, p_phone, p_notes, p_payment
  );
  update public.order_requests set order_id=v_order
    where customer_id=v_customer and request_id=p_request_id;
  return v_order;
end $$;

revoke all on function public.place_order_idempotent(
 uuid,jsonb,text,double precision,double precision,text,text,public.payment_method,uuid
) from public,anon;
grant execute on function public.place_order_idempotent(
 uuid,jsonb,text,double precision,double precision,text,text,public.payment_method,uuid
) to authenticated;

-- Old direct checkout cannot bypass the request uniqueness guarantee.
revoke execute on function public.place_order(
 uuid,jsonb,text,double precision,double precision,text,text,public.payment_method
) from public,anon,authenticated;
