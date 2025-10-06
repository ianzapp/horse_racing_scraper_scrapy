-- Debug model to see what distance values we have
select
    raw_data->>'race_distance' as race_distance,
    count(*) as count
from {{ source('public', 'raw_scraped_data') }}
where item_type = 'race_card'
  and raw_data->>'race_distance' is not null
group by raw_data->>'race_distance'
order by count desc
limit 20