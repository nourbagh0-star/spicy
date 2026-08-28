-- Spicy Maykop: initial branch locations.
-- Safe to run more than once: each address is inserted only once.
-- Coordinates use longitude first, then latitude, as required by PostGIS.

insert into public.branches (
  name,
  address,
  map_reference_url,
  location
)
select
  branch_data.name,
  branch_data.address,
  branch_data.map_reference_url,
  extensions.ST_SetSRID(
    extensions.ST_MakePoint(branch_data.longitude, branch_data.latitude),
    4326
  )
from (
  values
    (
      'Spicy — Пионерская',
      'Пионерская ул., 327, Майкоп',
      'https://yandex.ru/maps/-/CTDvZ6YD',
      40.0766841::numeric,
      44.6104805::numeric
    ),
    (
      'Spicy Lounge — Краснооктябрьская',
      'Краснооктябрьская ул., 17, Майкоп',
      'https://yandex.ru/maps/org/spicy_lounge/101106465422/',
      40.1038805::numeric,
      44.6052954::numeric
    ),
    (
      'Spicy — 2-я Крестьянская',
      '2-я Крестьянская ул., 17, Майкоп',
      'https://yandex.ru/maps/-/CTDv6Omi',
      40.1393529::numeric,
      44.6068660::numeric
    )
) as branch_data(name, address, map_reference_url, longitude, latitude)
where not exists (
  select 1
  from public.branches existing_branch
  where existing_branch.address = branch_data.address
);

-- Verification: this should return exactly three branches.
select
  name,
  address,
  round(extensions.ST_Y(location)::numeric, 6) as latitude,
  round(extensions.ST_X(location)::numeric, 6) as longitude
from public.branches
order by name;
