-- Refilly initial schema
create extension if not exists "pgcrypto";

create type user_role as enum ('customer','rider','owner');
create type order_status as enum ('pending','accepted','preparing','out_for_delivery','delivered','cancelled');
create type payment_method as enum ('cod','gcash','maya');
create type payment_status as enum ('unpaid','paid','refunded');

create table profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  phone text,
  role user_role not null default 'customer',
  station_id uuid, -- riders: station they work for
  created_at timestamptz not null default now()
);

create table stations (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid references profiles(id) on delete set null,
  name text not null,
  description text,
  address text,
  phone text,
  lat double precision not null,
  lng double precision not null,
  is_open boolean not null default true,
  created_at timestamptz not null default now()
);
alter table profiles add constraint profiles_station_fk foreign key (station_id) references stations(id) on delete set null;

create table categories (
  id uuid primary key default gen_random_uuid(),
  slug text unique not null,
  name text not null,
  icon text,
  sort int not null default 0
);

create table products (
  id uuid primary key default gen_random_uuid(),
  station_id uuid not null references stations(id) on delete cascade,
  category_id uuid references categories(id),
  name text not null,
  description text,
  unit text not null default 'pc',
  price numeric(10,2) not null check (price >= 0),
  is_available boolean not null default true,
  created_at timestamptz not null default now()
);

create table orders (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references profiles(id),
  station_id uuid not null references stations(id),
  rider_id uuid references profiles(id),
  status order_status not null default 'pending',
  payment_method payment_method not null default 'cod',
  payment_status payment_status not null default 'unpaid',
  payment_ref text, -- future GCash/Maya reference
  delivery_address text not null,
  delivery_lat double precision,
  delivery_lng double precision,
  contact_phone text,
  notes text,
  total numeric(10,2) not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references orders(id) on delete cascade,
  product_id uuid references products(id),
  product_name text not null,
  unit_price numeric(10,2) not null,
  quantity int not null check (quantity > 0),
  subtotal numeric(10,2) generated always as (unit_price * quantity) stored
);

create table rider_locations (
  rider_id uuid primary key references profiles(id) on delete cascade,
  order_id uuid references orders(id) on delete set null,
  lat double precision not null,
  lng double precision not null,
  heading double precision,
  updated_at timestamptz not null default now()
);

create index on products(station_id);
create index on orders(station_id, created_at);
create index on orders(customer_id);
create index on orders(rider_id);

-- auto profile on signup
create or replace function handle_new_user() returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into profiles(id, full_name, phone, role)
  values (new.id, new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'phone',
          coalesce((new.raw_user_meta_data->>'role')::user_role, 'customer'));
  return new;
end $$;
create trigger on_auth_user_created after insert on auth.users for each row execute function handle_new_user();

create or replace function touch_updated_at() returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end $$;
create trigger orders_touch before update on orders for each row execute function touch_updated_at();

-- helpers
create or replace function my_role() returns user_role language sql stable security definer set search_path = public as
$$ select role from profiles where id = auth.uid() $$;
create or replace function owns_station(sid uuid) returns boolean language sql stable security definer set search_path = public as
$$ select exists(select 1 from stations where id = sid and owner_id = auth.uid()) $$;

-- Atomic order placement: prices are read server-side
create or replace function place_order(p_station uuid, p_items jsonb, p_address text, p_lat double precision,
  p_lng double precision, p_phone text, p_notes text, p_payment payment_method default 'cod')
returns uuid language plpgsql security definer set search_path = public as $$
declare oid uuid; it jsonb; pr products%rowtype; tot numeric := 0;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  insert into orders(customer_id, station_id, delivery_address, delivery_lat, delivery_lng, contact_phone, notes, payment_method)
  values (auth.uid(), p_station, p_address, p_lat, p_lng, p_phone, p_notes, p_payment) returning id into oid;
  for it in select * from jsonb_array_elements(p_items) loop
    select * into pr from products where id = (it->>'product_id')::uuid and station_id = p_station and is_available;
    if not found then raise exception 'product unavailable'; end if;
    insert into order_items(order_id, product_id, product_name, unit_price, quantity)
    values (oid, pr.id, pr.name, pr.price, (it->>'quantity')::int);
    tot := tot + pr.price * (it->>'quantity')::int;
  end loop;
  update orders set total = tot where id = oid;
  return oid;
end $$;

-- Sales summary for owners
create or replace function station_sales(p_station uuid, p_from timestamptz, p_to timestamptz)
returns table(day date, orders bigint, revenue numeric) language sql stable security definer set search_path = public as $$
  select date_trunc('day', created_at at time zone 'Asia/Manila')::date, count(*), coalesce(sum(total),0)
  from orders where station_id = p_station and owns_station(p_station) and status = 'delivered'
    and created_at >= p_from and created_at < p_to
  group by 1 order by 1 $$;

create or replace function station_top_products(p_station uuid, p_from timestamptz, p_to timestamptz)
returns table(product_name text, qty bigint, revenue numeric) language sql stable security definer set search_path = public as $$
  select oi.product_name, sum(oi.quantity), sum(oi.subtotal)
  from order_items oi join orders o on o.id = oi.order_id
  where o.station_id = p_station and owns_station(p_station) and o.status = 'delivered'
    and o.created_at >= p_from and o.created_at < p_to
  group by 1 order by 3 desc limit 10 $$;

-- RLS
alter table profiles enable row level security;
alter table stations enable row level security;
alter table categories enable row level security;
alter table products enable row level security;
alter table orders enable row level security;
alter table order_items enable row level security;
alter table rider_locations enable row level security;

create policy "own profile" on profiles for select using (id = auth.uid());
create policy "owner sees customers/riders of station" on profiles for select using (
  exists(select 1 from orders o where o.customer_id = profiles.id and owns_station(o.station_id))
  or owns_station(profiles.station_id));
create policy "rider sees customer of assigned order" on profiles for select using (
  exists(select 1 from orders o where o.customer_id = profiles.id and o.rider_id = auth.uid()));
create policy "update own profile" on profiles for update using (id = auth.uid())
  with check (id = auth.uid() and role = my_role());
create policy "owner assigns riders" on profiles for update using (role = 'rider' and (station_id is null or owns_station(station_id)))
  with check (role = 'rider' and owns_station(station_id));
-- Owners can look up riders by phone to add them
create policy "owner sees unassigned riders" on profiles for select using (role = 'rider' and station_id is null and my_role() = 'owner');

create policy "stations public" on stations for select using (true);
create policy "owner insert station" on stations for insert with check (owner_id = auth.uid() and my_role() = 'owner');
create policy "owner update station" on stations for update using (owner_id = auth.uid());
create policy "owner delete station" on stations for delete using (owner_id = auth.uid());

create policy "categories public" on categories for select using (true);

create policy "products public" on products for select using (true);
create policy "owner manage products" on products for all using (owns_station(station_id)) with check (owns_station(station_id));

create policy "customer orders" on orders for select using (customer_id = auth.uid());
create policy "owner orders" on orders for select using (owns_station(station_id));
create policy "rider orders" on orders for select using (rider_id = auth.uid());
create policy "customer cancel pending" on orders for update using (customer_id = auth.uid() and status = 'pending')
  with check (status in ('pending','cancelled'));
create policy "owner update orders" on orders for update using (owns_station(station_id));
create policy "rider update orders" on orders for update using (rider_id = auth.uid())
  with check (rider_id = auth.uid() and status in ('out_for_delivery','delivered'));

create policy "items visible with order" on order_items for select using (
  exists(select 1 from orders o where o.id = order_id and (o.customer_id = auth.uid() or o.rider_id = auth.uid() or owns_station(o.station_id))));

create policy "rider writes own location" on rider_locations for all using (rider_id = auth.uid()) with check (rider_id = auth.uid());
create policy "customer/owner see rider location" on rider_locations for select using (
  exists(select 1 from orders o where o.rider_id = rider_locations.rider_id
    and o.status = 'out_for_delivery' and (o.customer_id = auth.uid() or owns_station(o.station_id))));

-- Realtime
alter publication supabase_realtime add table orders, rider_locations;
