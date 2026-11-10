-- Example model (already done for you): one row per meter with its customer's segment and city.
-- Run it with:  docker compose run --rm dbt run --select stg_meters
select
    m.meter_id,
    m.utility,
    m.install_date,
    c.customer_id,
    c.segment,
    c.city
from {{ source('meters', 'meters') }} as m
inner join {{ source('meters', 'customers') }} as c on c.customer_id = m.customer_id
