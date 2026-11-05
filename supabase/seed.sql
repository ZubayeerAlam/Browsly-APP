-- Reference data needed in every environment. Safe to run more than once.

insert into public.countries (code, name, currency_code, is_active)
values ('BD', 'Bangladesh', 'BDT', true)
on conflict (code) do nothing;

-- PLACEHOLDERS: confirm commission_block_limit and max_cod_order_value before
-- launch. The 1% commission rate is the agreed business rule.
insert into public.platform_settings (
  country_code, commission_rate, commission_block_limit, max_cod_order_value
)
values ('BD', 1.00, 5000.00, 50000.00)
on conflict (country_code) do nothing;

insert into public.regions (country_code, level, name)
select 'BD', 'division'::public.region_level, division
from unnest(array[
  'Barishal', 'Chattogram', 'Dhaka', 'Khulna',
  'Mymensingh', 'Rajshahi', 'Rangpur', 'Sylhet'
]) as division
on conflict on constraint regions_unique_name do nothing;

insert into public.regions (country_code, parent_id, level, name)
select 'BD', parent.id, 'district'::public.region_level, district.name
from (
  values
    ('Barishal', 'Barguna'), ('Barishal', 'Barishal'), ('Barishal', 'Bhola'),
    ('Barishal', 'Jhalokathi'), ('Barishal', 'Patuakhali'), ('Barishal', 'Pirojpur'),
    ('Chattogram', 'Bandarban'), ('Chattogram', 'Brahmanbaria'), ('Chattogram', 'Chandpur'),
    ('Chattogram', 'Chattogram'), ('Chattogram', 'Cox''s Bazar'), ('Chattogram', 'Cumilla'),
    ('Chattogram', 'Feni'), ('Chattogram', 'Khagrachhari'), ('Chattogram', 'Lakshmipur'),
    ('Chattogram', 'Noakhali'), ('Chattogram', 'Rangamati'),
    ('Dhaka', 'Dhaka'), ('Dhaka', 'Faridpur'), ('Dhaka', 'Gazipur'),
    ('Dhaka', 'Gopalganj'), ('Dhaka', 'Kishoreganj'), ('Dhaka', 'Madaripur'),
    ('Dhaka', 'Manikganj'), ('Dhaka', 'Munshiganj'), ('Dhaka', 'Narayanganj'),
    ('Dhaka', 'Narsingdi'), ('Dhaka', 'Rajbari'), ('Dhaka', 'Shariatpur'),
    ('Dhaka', 'Tangail'),
    ('Khulna', 'Bagerhat'), ('Khulna', 'Chuadanga'), ('Khulna', 'Jashore'),
    ('Khulna', 'Jhenaidah'), ('Khulna', 'Khulna'), ('Khulna', 'Kushtia'),
    ('Khulna', 'Magura'), ('Khulna', 'Meherpur'), ('Khulna', 'Narail'),
    ('Khulna', 'Satkhira'),
    ('Mymensingh', 'Jamalpur'), ('Mymensingh', 'Mymensingh'),
    ('Mymensingh', 'Netrokona'), ('Mymensingh', 'Sherpur'),
    ('Rajshahi', 'Bogura'), ('Rajshahi', 'Chapainawabganj'), ('Rajshahi', 'Joypurhat'),
    ('Rajshahi', 'Naogaon'), ('Rajshahi', 'Natore'), ('Rajshahi', 'Pabna'),
    ('Rajshahi', 'Rajshahi'), ('Rajshahi', 'Sirajganj'),
    ('Rangpur', 'Dinajpur'), ('Rangpur', 'Gaibandha'), ('Rangpur', 'Kurigram'),
    ('Rangpur', 'Lalmonirhat'), ('Rangpur', 'Nilphamari'), ('Rangpur', 'Panchagarh'),
    ('Rangpur', 'Rangpur'), ('Rangpur', 'Thakurgaon'),
    ('Sylhet', 'Habiganj'), ('Sylhet', 'Moulvibazar'),
    ('Sylhet', 'Sunamganj'), ('Sylhet', 'Sylhet')
) as district (division, name)
join public.regions as parent
  on parent.country_code = 'BD'
  and parent.level = 'division'
  and parent.name = district.division
on conflict on constraint regions_unique_name do nothing;

-- Starter categories. Admins manage these from Step 7.
insert into public.categories (name, slug, icon, sort_order)
values
  ('Fashion', 'fashion', 'checkroom', 10),
  ('Electronics', 'electronics', 'devices', 20),
  ('Home & Living', 'home-living', 'chair', 30),
  ('Beauty', 'beauty', 'spa', 40),
  ('Sports', 'sports', 'sports_soccer', 50),
  ('Books', 'books', 'menu_book', 60)
on conflict (slug) do nothing;

insert into public.categories (parent_id, name, slug, icon, sort_order)
select parent.id, child.name, child.slug, parent.icon, child.sort_order
from (
  values
    ('fashion', 'Men', 'fashion-men', 10),
    ('fashion', 'Women', 'fashion-women', 20),
    ('fashion', 'Shoes', 'fashion-shoes', 30),
    ('electronics', 'Phones', 'electronics-phones', 10),
    ('electronics', 'Audio', 'electronics-audio', 20),
    ('electronics', 'Accessories', 'electronics-accessories', 30),
    ('home-living', 'Furniture', 'home-furniture', 10),
    ('home-living', 'Kitchen', 'home-kitchen', 20)
) as child (parent_slug, name, slug, sort_order)
join public.categories as parent on parent.slug = child.parent_slug
on conflict (slug) do nothing;
