-- Ultra-safe version - no distance parsing, just store raw values
{{
  config(
    materialized='table'
  )
}}

with source_data as (
    select
        id,
        spider_name,
        source_url,
        raw_data,
        data_hash,
        created_at
    from {{ source('public', 'raw_scraped_data') }}
    where item_type = 'race_card'
    limit 100  -- Test with just 100 records first
),

parsed_data as (
    select
        id,
        spider_name,
        source_url,
        data_hash,
        created_at,

        -- Basic race information
        trim(raw_data->>'track_name') as track_name,
        (raw_data->>'race_date')::date as race_date,
        (raw_data->>'race_number')::integer as race_number,

        -- Race details - store as text for now
        trim(raw_data->>'race_distance') as race_distance,
        trim(raw_data->>'race_restrictions') as race_restrictions,
        trim(raw_data->>'race_purse') as race_purse,
        trim(raw_data->>'race_wager') as race_wager,
        trim(raw_data->>'race_report') as race_report,

        -- Extract surface type safely
        case
            when upper(trim(raw_data->>'race_distance')) like '%DIRT%' then 'Dirt'
            when upper(trim(raw_data->>'race_distance')) like '%TURF%' then 'Turf'
            when upper(trim(raw_data->>'race_distance')) like '%SYNTHETIC%' then 'Synthetic'
            when upper(trim(raw_data->>'race_distance')) like '%ALL WEATHER%' then 'All Weather'
            else 'Unknown'
        end as surface_type

    from source_data
)

select * from parsed_data