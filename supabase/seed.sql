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
