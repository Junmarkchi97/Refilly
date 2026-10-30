-- Default images for seeded products (files in supabase/seed-images, uploaded to product-images/defaults/).
update public.products set image_url = 'https://eregmlruwyzrziihihbt.supabase.co/storage/v1/object/public/product-images/defaults/' ||
  case when name ilike '%alkaline%' then 'alkaline.jpg'
       when name ilike '%mineral%' then 'mineral.jpg'
       when name ilike '%container%' then 'container.jpg'
       else 'purified.jpg' end
where image_url is null;
