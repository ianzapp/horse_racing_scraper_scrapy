{{
  config(
    materialized='table',
    unique_key='owner_key'
  )
}}

with owner_data as (
    select
        owner_name,
        max(scraped_dt) as update_dt,
        max(scraped_dt::date) as last_seen_dt,
        count(*) as total_horses
    from {{ ref('stg_hrn_speed_results') }}
    where owner_name is not null and owner_name != ''
    group by owner_name
),

final as (
    select
        {{ dbt_utils.generate_surrogate_key(['owner_name']) }} as owner_key,
        owner_name,
        total_horses,

        -- Temporal columns (standardized at end)
        update_dt,
        last_seen_dt,
        case
            when last_seen_dt >= current_date - interval '90 days' then true
            when last_seen_dt >= current_date - interval '365 days' then true
            else false
        end as is_active,
        current_timestamp as create_dt
    from owner_data
)

select * from final
