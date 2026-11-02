-- Saved riders per station so owners can re-use name + phone on later orders.
create table if not exists public.station_riders (
  id uuid primary key default gen_random_uuid(),
  station_id uuid not null references public.stations(id) on delete cascade,
  name text not null,
  phone text not null,
  last_used_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  unique (station_id, phone)
);

create index if not exists station_riders_station_last_used_idx
  on public.station_riders (station_id, last_used_at desc);

alter table public.station_riders enable row level security;

drop policy if exists "owner manages station riders" on public.station_riders;
create policy "owner manages station riders" on public.station_riders
  for all to authenticated
  using (public.owns_station(station_id))
  with check (public.owns_station(station_id));
