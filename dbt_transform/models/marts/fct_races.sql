{{
  config(
    materialized='table',
    unique_key='race_key'
  )
}}

with race_cards as (
    select * from {{ ref('stg_race_cards') }}
),

tracks as (
    select * from {{ ref('dim_tracks') }}
),

race_details as (
    select
        rc.*,
        t.track_key
    from race_cards rc
    left join tracks t on rc.track_name = t.track_name
),

final as (
    select
        {{ dbt_utils.generate_surrogate_key(['track_name', 'race_date', 'race_number']) }} as race_key,
        track_key,
        track_name,
        race_date,
        race_number,
        race_time,
        race_distance,
        distance_furlongs,
        surface_type,
        race_restrictions,
        race_purse,
        purse_amount,
        race_wager,
        race_report,
        source_url,
        created_at as scraped_at
    from race_details
)

select * from final