{{
  config(
    materialized='table',
    unique_key='jockey_key'
  )
}}

with jockey_data as (
    select
        jockey,
        max(scraped_dt) as update_dt,
        max(scraped_dt::date) as last_seen_dt,
        count(*) as total_rides
    from {{ ref('stg_race_entries') }}
    where jockey is not null and jockey != ''
    group by jockey
),

final as (
    select
        {{ dbt_utils.generate_surrogate_key(['jockey']) }} as jockey_key,
        jockey as jockey_name,
        total_rides,

        -- Temporal columns (standardized at end)
        update_dt,
        last_seen_dt,
        case
            when last_seen_dt >= current_date - interval '90 days' then true
            when last_seen_dt >= current_date - interval '365 days' then true
            else false
        end as is_active,
        current_timestamp as create_dt
    from jockey_data
)

select * from final