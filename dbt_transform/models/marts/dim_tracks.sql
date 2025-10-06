{{
  config(
    materialized='table',
    unique_key='track_key'
  )
}}

with track_info as (
    select
        track_name,
        track_location,
        track_city,
        track_state,
        track_description,
        track_website,
        max(created_at) as last_updated
    from {{ ref('stg_track_info') }}
    group by 1, 2, 3, 4, 5, 6
),

track_names_from_entries as (
    select distinct
        track_name,
        null as track_location,
        null as track_city,
        null as track_state,
        null as track_description,
        null as track_website,
        max(created_at) as last_updated
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
            max(case when track_location is not null then track_location end),
            max(track_location)
        ) as track_location,
        coalesce(
            max(case when track_city is not null then track_city end),
            max(track_city)
        ) as track_city,
        coalesce(
            max(case when track_state is not null then track_state end),
            max(track_state)
        ) as track_state,
        coalesce(
            max(case when track_description is not null then track_description end),
            max(track_description)
        ) as track_description,
        coalesce(
            max(case when track_website is not null then track_website end),
            max(track_website)
        ) as track_website,
        max(last_updated) as last_updated
    from all_tracks
    group by track_name
),

final as (
    select
        {{ dbt_utils.generate_surrogate_key(['track_name']) }} as track_key,
        track_name,
        track_location,
        track_city,
        track_state,
        track_description,
        track_website,
        last_updated,
        current_timestamp as created_at
    from deduplicated_tracks
)

select * from final