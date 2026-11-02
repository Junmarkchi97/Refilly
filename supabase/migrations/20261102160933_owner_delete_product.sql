-- Owners can remove a product after customers have ordered it.
-- Past order lines keep the saved name and price; only the product link is cleared.
do $$
declare constraint_name text;
begin
  for constraint_name in
    select con.conname
    from pg_constraint con
    join pg_class rel on rel.oid = con.conrelid
    join pg_namespace nsp on nsp.oid = rel.relnamespace
    where nsp.nspname = 'public'
      and rel.relname = 'order_items'
      and con.contype = 'f'
      and pg_get_constraintdef(con.oid) ilike '%products%'
  loop
    execute format('alter table public.order_items drop constraint %I', constraint_name);
  end loop;
end $$;

alter table public.order_items
  add constraint order_items_product_id_fkey
  foreign key (product_id) references public.products(id) on delete set null;
