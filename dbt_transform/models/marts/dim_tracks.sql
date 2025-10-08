{{
  config(
    materialized='table',
    unique_key='track_key'
  )
}}

with track_info as (
    select
        track_name,
        track_city,
        track_state,
        track_country,
        track_description,
        track_website,
        max(created_at) as last_updated,
        max(last_seen_date) as last_seen_date
    from {{ ref('stg_track_info') }}
    group by 1, 2, 3, 4, 5, 6
),

track_names_from_entries as (
    select distinct
        track_name,
        null as track_city,
        null as track_state,
        'USA' as track_country,  -- Default to USA for entries without location data
        null as track_description,
        null as track_website,
        max(created_at) as last_updated,
        max(created_at::date) as last_seen_date
    from {{ ref('stg_race_entries') }}
    where track_name is not null
    group by 1
),

all_tracks as (
    select * from track_info
    union all
    select * from track_names_from_entries
),

deduplicated_tracks as (
    select
        track_name,
        -- Take the most complete information available
        coalesce(
            max(case when track_city is not null then track_city end),
            max(track_city)
        ) as track_city,
        coalesce(
            max(case when track_state is not null then track_state end),
            max(track_state)
        ) as track_state,
        coalesce(
            max(case when track_country is not null and track_country != 'USA' then track_country end),
            max(case when track_country is not null then track_country end),
            'USA'
        ) as track_country,
        coalesce(
            max(case when track_description is not null then track_description end),
            max(track_description)
        ) as track_description,
        coalesce(
            max(case when track_website is not null then track_website end),
            max(track_website)
        ) as track_website,
        max(last_updated) as last_updated,
        max(last_seen_date) as last_seen_date
    from all_tracks
    group by track_name
),

final as (
    select
        {{ dbt_utils.generate_surrogate_key(['track_name']) }} as track_key,
        track_name,
        track_city,
        track_state,
        track_country,
        track_description,
        track_website,
        last_updated,
        last_seen_date,
        -- Track activity status based on recent activity
        case
            when last_seen_date >= current_date - interval '90 days' then true
            when last_seen_date >= current_date - interval '365 days' then true  -- Keep tracks active within a year
            else false  -- Mark as inactive if not seen for over a year
        end as is_active,
        -- Days since last seen
        current_date - last_seen_date as days_since_last_seen,
        current_timestamp as created_at
    from deduplicated_tracks
)

select * from final