{{
  config(
    materialized='table',
    unique_key='jockey_key'
  )
}}

with jockey_data as (
    select
        jockey,
        max(created_at) as last_seen,
        count(*) as total_rides
    from {{ ref('stg_race_entries') }}
    where jockey is not null and jockey != ''
    group by jockey
),

final as (
    select
        {{ dbt_utils.generate_surrogate_key(['jockey']) }} as jockey_key,
        jockey as jockey_name,
        last_seen,
        total_rides,
        current_timestamp as created_at
    from jockey_data
)

select * from final