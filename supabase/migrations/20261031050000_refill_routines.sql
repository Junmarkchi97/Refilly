-- Refill Routine MVP. All routine mutations use authenticated, owner-checked RPCs.
-- The routine only suggests an order; it NEVER places or charges for one.
create table if not exists public.refill_routines (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references public.profiles(id) on delete cascade,
  source_order_id uuid not null references public.orders(id) on delete cascade,
  station_id uuid not null references public.stations(id),
  interval_days integer not null check (interval_days between 1 and 365),
  next_due_on date not null,
  last_order_id uuid references public.orders(id) on delete set null,
  last_notified_due_on date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (customer_id, source_order_id)
);
create index if not exists refill_routines_customer_due_idx
  on public.refill_routines(customer_id, next_due_on);

alter table public.refill_routines enable row level security;
drop policy if exists "customer reads own routines" on public.refill_routines;
create policy "customer reads own routines" on public.refill_routines
  for select to authenticated using(customer_id = (select auth.uid()));
revoke all on public.refill_routines from anon, authenticated;
grant select on public.refill_routines to authenticated;

create or replace function public.save_refill_routine(p_order uuid, p_interval_days integer)
returns uuid language plpgsql security definer set search_path = '' as $$
declare source_order public.orders%rowtype; routine_id uuid;
begin
  if auth.uid() is null then raise exception 'Sign in required'; end if;
  if p_interval_days is null or p_interval_days not between 1 and 365
    then raise exception 'Interval must be 1 to 365 days'; end if;
  select * into source_order from public.orders
   where id = p_order and customer_id = auth.uid() and status = 'delivered';
  if not found then raise exception 'Only your delivered orders can become routines'; end if;
  if not exists(select 1 from public.order_items
    where order_id = p_order and product_id is not null)
    then raise exception 'This order has no reusable products'; end if;

  insert into public.refill_routines
    (customer_id, source_order_id, station_id, interval_days, next_due_on)
  values (auth.uid(), p_order, source_order.station_id, p_interval_days,
          current_date + p_interval_days)
  on conflict(customer_id, source_order_id) do update
    set interval_days = excluded.interval_days,
        next_due_on = excluded.next_due_on,
        last_notified_due_on = null,
        updated_at = now()
  returning id into routine_id;
  return routine_id;
end $$;
revoke all on function public.save_refill_routine(uuid,integer) from public,anon;
grant execute on function public.save_refill_routine(uuid,integer) to authenticated;

create or replace function public.manage_refill_routine(
  p_routine uuid, p_action text, p_interval_days integer default null)
returns void language plpgsql security definer set search_path = '' as $$
declare r public.refill_routines%rowtype;
begin
  if auth.uid() is null then raise exception 'Sign in required'; end if;
  select * into r from public.refill_routines
    where id = p_routine and customer_id = auth.uid() for update;
  if not found then raise exception 'Routine not found'; end if;
  if p_action = 'snooze' then
    update public.refill_routines set next_due_on = greatest(next_due_on, current_date) + 3,
      last_notified_due_on = null, updated_at = now() where id = r.id;
  elsif p_action = 'skip' then
    update public.refill_routines set next_due_on = greatest(next_due_on, current_date) + interval_days,
      last_notified_due_on = null, updated_at = now() where id = r.id;
  elsif p_action = 'frequency' then
    if p_interval_days is null or p_interval_days not between 1 and 365
      then raise exception 'Interval must be 1 to 365 days'; end if;
    update public.refill_routines set interval_days = p_interval_days,
      next_due_on = current_date + p_interval_days,
      last_notified_due_on = null, updated_at = now() where id = r.id;
  elsif p_action = 'remove' then
    delete from public.refill_routines where id = r.id;
  else
    raise exception 'Unsupported routine action';
  end if;
end $$;
revoke all on function public.manage_refill_routine(uuid,text,integer) from public,anon;
grant execute on function public.manage_refill_routine(uuid,text,integer) to authenticated;

-- Only associate an order after normal checkout has already completed.
-- Prevents the same order from being attached to multiple routines.
create unique index if not exists refill_routines_last_order_once_idx
  on public.refill_routines(last_order_id) where last_order_id is not null;
create or replace function public.record_refill_routine_order(p_routine uuid,p_order uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare r public.refill_routines%rowtype; o public.orders%rowtype;
begin
  if auth.uid() is null then raise exception 'Sign in required'; end if;
  select * into r from public.refill_routines where id=p_routine
    and customer_id=auth.uid() for update;
  if not found then raise exception 'Routine not found'; end if;
  select * into o from public.orders where id=p_order and customer_id=auth.uid()
    and station_id=r.station_id and status <> 'cancelled';
  if not found then raise exception 'Order does not belong to this routine'; end if;
  update public.refill_routines set last_order_id=p_order,
    next_due_on=current_date + interval_days,
    last_notified_due_on=null,updated_at=now() where id=r.id;
end $$;
revoke all on function public.record_refill_routine_order(uuid,uuid) from public,anon;
grant execute on function public.record_refill_routine_order(uuid,uuid) to authenticated;

-- Also provisions the private in-app notifications inbox on deployments that
-- have not yet applied the water_marketplace migration. Existing inboxes
-- remain intact; subsequent marketplace migration policies can coexist.
create table if not exists public.user_notifications(
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  order_id uuid references public.orders(id) on delete cascade,
  title text not null,
  body text not null,
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists user_notifications_user_created
  on public.user_notifications(user_id, created_at desc);
alter table public.user_notifications enable row level security;
drop policy if exists "routine notifications owner read" on public.user_notifications;
create policy "routine notifications owner read" on public.user_notifications
  for select to authenticated using (user_id = (select auth.uid()));
drop policy if exists "routine notifications owner update" on public.user_notifications;
create policy "routine notifications owner update" on public.user_notifications
  for update to authenticated using(user_id = (select auth.uid()))
  with check(user_id = (select auth.uid()));
revoke all on public.user_notifications from anon, authenticated;
grant select on public.user_notifications to authenticated;
grant update(is_read) on public.user_notifications to authenticated;

-- Reminder uniqueness is persisted in the database, even across devices.
-- Notifications are only created when the customer opens the app / routine tab;
-- this is an in-app reminder, not a push notification scheduler.
create or replace function public.claim_refill_reminders()
returns integer language plpgsql security definer set search_path = '' as $$
declare r record; notices integer := 0;
begin
  if auth.uid() is null then raise exception 'Sign in required'; end if;
  for r in
    select id, source_order_id, next_due_on from public.refill_routines
    where customer_id=auth.uid() and next_due_on <= current_date
      and last_notified_due_on is distinct from next_due_on
    for update skip locked
  loop
    update public.refill_routines set last_notified_due_on = r.next_due_on,
      updated_at=now() where id=r.id;
    insert into public.user_notifications(user_id,order_id,title,body)
    values(auth.uid(),r.source_order_id,'Time to refill?',
      'Your saved essential may be running low. Review your Refill Routine before ordering.');
    notices := notices + 1;
  end loop;
  return notices;
end $$;
revoke all on function public.claim_refill_reminders() from public,anon;
grant execute on function public.claim_refill_reminders() to authenticated;
