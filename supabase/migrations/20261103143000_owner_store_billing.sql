-- Record an App Store or Play Billing subscription for a station owner.
-- The store charges the Apple ID or Google account when the free trial ends.
-- This function only stores the purchase the app already completed with the store.

alter table public.owner_subscriptions
  add column if not exists status text not null default 'pending',
  add column if not exists store text,
  add column if not exists product_id text,
  add column if not exists store_transaction_id text,
  add column if not exists current_period_end timestamptz,
  add column if not exists will_renew boolean;

update public.owner_subscriptions
set status = 'sponsored'
where plan = 'sponsored' and status = 'pending';

alter table public.owner_subscriptions
  drop constraint if exists owner_subscriptions_status_check;
alter table public.owner_subscriptions
  add constraint owner_subscriptions_status_check
  check (status in ('pending', 'trialing', 'active', 'expired', 'sponsored'));

alter table public.owner_subscriptions
  drop constraint if exists owner_subscriptions_store_check;
alter table public.owner_subscriptions
  add constraint owner_subscriptions_store_check
  check (store is null or store in ('app_store', 'play_store'));

create or replace function public.record_owner_store_purchase(
  p_plan text,
  p_product_id text,
  p_transaction_id text,
  p_store text,
  p_period_end timestamptz default null
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_end timestamptz := coalesce(p_period_end, now() + interval '7 days');
  v_status text := case
    when p_period_end is not null and p_period_end <= now() then 'expired'
    when v_end <= now() + interval '8 days' then 'trialing'
    else 'active'
  end;
begin
  if auth.uid() is null then
    raise exception 'Please sign in first.';
  end if;
  if p_plan not in ('monthly', 'yearly') then
    raise exception 'Choose a monthly or yearly plan.';
  end if;
  if p_store not in ('app_store', 'play_store') then
    raise exception 'Unknown store.';
  end if;
  if (p_plan = 'monthly' and p_product_id is distinct from 'refilly_owner_monthly')
     or (p_plan = 'yearly' and p_product_id is distinct from 'refilly_owner_yearly') then
    raise exception 'That subscription does not match the selected plan.';
  end if;
  if p_transaction_id is null or length(trim(p_transaction_id)) < 3 or length(p_transaction_id) > 2048 then
    raise exception 'That purchase could not be recorded.';
  end if;
  if p_period_end is not null and (p_period_end < now() - interval '1 day' or p_period_end > now() + interval '400 days') then
    raise exception 'That subscription period is not valid.';
  end if;

  insert into public.owner_subscriptions (
    user_id, plan, status, store, product_id, store_transaction_id, current_period_end, trial_ends_at, will_renew
  ) values (
    auth.uid(), p_plan, v_status, p_store, p_product_id, trim(p_transaction_id), v_end, v_end, v_status <> 'expired'
  )
  on conflict (user_id) do update
    set plan = case
          when owner_subscriptions.plan = 'sponsored' and owner_subscriptions.sponsored_until > now()
          then owner_subscriptions.plan else excluded.plan end,
        status = case
          when owner_subscriptions.plan = 'sponsored' and owner_subscriptions.sponsored_until > now()
          then 'sponsored' else excluded.status end,
        store = excluded.store,
        product_id = excluded.product_id,
        store_transaction_id = excluded.store_transaction_id,
        current_period_end = case
          when p_period_end is not null then excluded.current_period_end
          when owner_subscriptions.current_period_end is not null then owner_subscriptions.current_period_end
          else excluded.current_period_end end,
        trial_ends_at = case
          when owner_subscriptions.plan = 'sponsored' and owner_subscriptions.sponsored_until > now()
          then owner_subscriptions.trial_ends_at
          when p_period_end is not null then excluded.trial_ends_at
          else coalesce(owner_subscriptions.trial_ends_at, excluded.trial_ends_at) end,
        will_renew = excluded.will_renew,
        updated_at = now();
end;
$$;

revoke all on function public.record_owner_store_purchase(text, text, text, text, timestamptz) from public, anon;
grant execute on function public.record_owner_store_purchase(text, text, text, text, timestamptz) to authenticated;

create or replace function public.redeem_owner_voucher(p_code text)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v public.owner_vouchers;
  v_until timestamptz;
begin
  if auth.uid() is null then
    raise exception 'Please sign in first.';
  end if;

  select * into v from public.owner_vouchers
  where code = upper(trim(p_code))
  for update;

  if not found then
    raise exception 'That voucher code is not valid.';
  end if;
  if v.expires_at is not null and v.expires_at < now() then
    raise exception 'That voucher code has expired.';
  end if;
  if exists (select 1 from public.owner_subscriptions where user_id = auth.uid() and voucher_code = v.code) then
    raise exception 'You already used this voucher.';
  end if;
  if v.redemptions >= v.max_redemptions then
    raise exception 'That voucher code has already been used.';
  end if;

  v_until := now() + make_interval(months => v.free_months);

  update public.owner_vouchers set redemptions = redemptions + 1 where code = v.code;

  insert into public.owner_subscriptions (user_id, plan, voucher_code, sponsored_until, status)
  values (auth.uid(), 'sponsored', v.code, v_until, 'sponsored')
  on conflict (user_id) do update
    set plan = 'sponsored', voucher_code = excluded.voucher_code,
        sponsored_until = excluded.sponsored_until, status = 'sponsored', updated_at = now();

  return json_build_object('free_months', v.free_months, 'sponsored_until', v_until);
end;
$$;

revoke all on function public.redeem_owner_voucher(text) from public, anon;
grant execute on function public.redeem_owner_voucher(text) to authenticated;
