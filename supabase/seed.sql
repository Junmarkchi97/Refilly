-- Sample data (stations without owners; claim one by setting owner_id to your owner user's id)
insert into categories(slug,name,icon,sort) values
 ('water','Water','water_drop',1),('rice','Rice','rice_bowl',2),('lpg','LPG','local_fire_department',3),('essentials','Daily Essentials','shopping_basket',4)
on conflict (slug) do nothing;

with s as (
 insert into stations(name,address,phone,lat,lng,description) values
  ('AquaPure Refilling - Cubao','Aurora Blvd, Cubao, Quezon City','0917 000 0001',14.6198,121.0537,'Purified & alkaline water'),
  ('Crystal Clear Station - Makati','Chino Roces Ave, Makati','0917 000 0002',14.5547,121.0170,'Mineral and purified'),
  ('H2O Hub - Pasig','Ortigas Ave, Pasig','0917 000 0003',14.5869,121.0614,'24/7 refills'),
  ('BlueDrop - Manila','España Blvd, Sampaloc, Manila','0917 000 0004',14.6091,120.9890,'Student-friendly prices'),
  ('PureFlow - Taguig','BGC, Taguig','0917 000 0005',14.5509,121.0509,'Premium alkaline')
 returning id
)
insert into products(station_id,category_id,name,unit,price)
select s.id, c.id, p.name, p.unit, p.price from s
cross join (values
  ('water','Purified Water Refill (5 gal)','gallon',30.00),
  ('water','Alkaline Water Refill (5 gal)','gallon',45.00),
  ('water','Mineral Water Refill (5 gal)','gallon',35.00),
  ('water','New 5-gal Container w/ Water','pc',250.00)
) as p(cat,name,unit,price)
join categories c on c.slug = p.cat;
