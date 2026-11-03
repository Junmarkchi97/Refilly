-- Free 7-day trial when an applicant picks monthly or yearly.

alter table public.owner_subscriptions
  add column if not exists trial_ends_at timestamptz;

create or replace function public.choose_owner_plan(p_plan text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_trial timestamptz := now() + interval '7 days';
begin
  if auth.uid() is null then
    raise exception 'Please sign in first.';
  end if;
  if p_plan not in ('monthly', 'yearly') then
    raise exception 'Choose a monthly or yearly plan.';
  end if;

  insert into public.owner_subscriptions (user_id, plan, trial_ends_at)
  values (auth.uid(), p_plan, v_trial)
  on conflict (user_id) do update
    set plan = case
          when owner_subscriptions.plan = 'sponsored'
               and owner_subscriptions.sponsored_until > now()
          then owner_subscriptions.plan
          else excluded.plan
        end,
        trial_ends_at = case
          when owner_subscriptions.plan = 'sponsored'
               and owner_subscriptions.sponsored_until > now()
          then owner_subscriptions.trial_ends_at
          when owner_subscriptions.trial_ends_at is null
          then excluded.trial_ends_at
          else owner_subscriptions.trial_ends_at
        end,
        updated_at = now();
end;
$$;

revoke all on function public.choose_owner_plan(text) from public, anon;
grant execute on function public.choose_owner_plan(text) to authenticated;
