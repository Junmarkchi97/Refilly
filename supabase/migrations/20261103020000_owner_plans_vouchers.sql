-- Station-owner plans and sponsor vouchers.
-- Monthly ₱249; yearly 40% off (₱1,793). Vouchers grant free months (e.g. 6-month sponsorships).

create table if not exists public.owner_vouchers (
  code text primary key check (code = upper(code) and length(code) between 4 and 32),
  free_months int not null default 6 check (free_months between 1 and 24),
  max_redemptions int not null default 1 check (max_redemptions > 0),
  redemptions int not null default 0,
  expires_at timestamptz,
  note text,
  created_at timestamptz not null default now()
);

create table if not exists public.owner_subscriptions (
  user_id uuid primary key references auth.users(id) on delete cascade,
  plan text not null check (plan in ('monthly', 'yearly', 'sponsored')),
  voucher_code text references public.owner_vouchers(code),
  sponsored_until timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.owner_vouchers enable row level security;
alter table public.owner_subscriptions enable row level security;

drop policy if exists owner_subscriptions_select_own on public.owner_subscriptions;
create policy owner_subscriptions_select_own on public.owner_subscriptions
  for select using (user_id = auth.uid());

-- Vouchers are never readable from the client; redemption goes through the RPC.

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

  insert into public.owner_subscriptions (user_id, plan, voucher_code, sponsored_until)
  values (auth.uid(), 'sponsored', v.code, v_until)
  on conflict (user_id) do update
    set plan = 'sponsored', voucher_code = excluded.voucher_code,
        sponsored_until = excluded.sponsored_until, updated_at = now();

  return json_build_object('free_months', v.free_months, 'sponsored_until', v_until);
end;
$$;

revoke all on function public.redeem_owner_voucher(text) from public, anon;
grant execute on function public.redeem_owner_voucher(text) to authenticated;

create or replace function public.choose_owner_plan(p_plan text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Please sign in first.';
  end if;
  if p_plan not in ('monthly', 'yearly') then
    raise exception 'Choose a monthly or yearly plan.';
  end if;
  insert into public.owner_subscriptions (user_id, plan)
  values (auth.uid(), p_plan)
  on conflict (user_id) do update
    set plan = case when owner_subscriptions.plan = 'sponsored'
                     and owner_subscriptions.sponsored_until > now()
                    then owner_subscriptions.plan else excluded.plan end,
        updated_at = now();
end;
$$;

revoke all on function public.choose_owner_plan(text) from public, anon;
grant execute on function public.choose_owner_plan(text) to authenticated;

-- Example sponsor voucher (6 free months, 20 shops). Edit or remove before running.
-- insert into public.owner_vouchers (code, free_months, max_redemptions, note)
-- values ('REFILLY6', 6, 20, 'Launch sponsorship');
