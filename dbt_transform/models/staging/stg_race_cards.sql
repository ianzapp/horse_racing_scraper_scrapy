{{
  config(
    materialized='incremental',
    unique_key='id',
    on_schema_change='fail'
  )
}}

with source_data as (
    select
        id,
        spider_name,
        raw_data,
        source_url,
        data_hash,
        created_at as scraped_dt
    from {{ source('public', 'raw_scraped_data') }}
    where item_type = 'race_card'

    {% if is_incremental() %}
        and created_at > (select max(scraped_dt) from {{ this }})
    {% endif %}
),

parsed_data as (
    select
        id,
        spider_name,

        -- Basic race information
        trim(raw_data->>'track_name') as track_name,
        (raw_data->>'race_date')::date as race_date,
        (raw_data->>'race_number')::integer as race_number,

        -- Race timing
        case
            when raw_data->>'race_time' is not null and raw_data->>'race_time' != ''
            then (raw_data->>'race_time')::timestamp
            else null
        end as race_time,

        -- Race details
        trim(raw_data->>'race_distance') as race_distance,
        trim(raw_data->>'race_restrictions') as race_restrictions,
        trim(raw_data->>'race_purse') as race_purse,
        trim(raw_data->>'race_wager') as race_wager,
        trim(raw_data->>'race_report') as race_report,

        -- Extract purse amount if possible
        case
            when raw_data->>'race_purse' ~ '\$[0-9,]+' then
                regexp_replace(
                    regexp_replace(raw_data->>'race_purse', '[^0-9]', '', 'g'),
                    '^0+', ''
                )::numeric
            else null
        end as purse_amount,

        -- Extract distance in furlongs (safe version with proper error handling)
        case
            when raw_data->>'race_distance' is not null and raw_data->>'race_distance' != '' then
                case
                    -- Extract yards and convert to furlongs (1 furlong = 220 yards)
                    when upper(raw_data->>'race_distance') ~ '[0-9]+\s*Y' then
                        case
                            when regexp_replace(raw_data->>'race_distance', '^([0-9]+)\s*Y.*', '\1') ~ '^[0-9]+$' then
                                (regexp_replace(raw_data->>'race_distance', '^([0-9]+)\s*Y.*', '\1'))::numeric / 220.0
                            else null
                        end
                    -- Extract furlongs
                    when upper(raw_data->>'race_distance') ~ '[0-9]+\s*F' then
                        case
                            when regexp_replace(raw_data->>'race_distance', '^([0-9]+)\s*F.*', '\1') ~ '^[0-9]+$' then
                                (regexp_replace(raw_data->>'race_distance', '^([0-9]+)\s*F.*', '\1'))::numeric
                            else null
                        end
                    -- Extract miles and convert to furlongs (1 mile = 8 furlongs)
                    when upper(raw_data->>'race_distance') ~ '[0-9]+\s*M' then
                        case
                            when regexp_replace(raw_data->>'race_distance', '^([0-9]+)\s*M.*', '\1') ~ '^[0-9]+$' then
                                (regexp_replace(raw_data->>'race_distance', '^([0-9]+)\s*M.*', '\1'))::numeric * 8.0
                            else null
                        end
                    else null
                end
            else null
        end as distance_furlongs,

        -- Extract surface type
        case
            when upper(raw_data->>'race_distance') like '%DIRT%' then 'Dirt'
            when upper(raw_data->>'race_distance') like '%TURF%' then 'Turf'
            when upper(raw_data->>'race_distance') like '%SYNTHETIC%' then 'Synthetic'
            when upper(raw_data->>'race_distance') like '%ALL WEATHER%' then 'All Weather'
            else 'Unknown'
        end as surface_type,

        -- Metadata (at end)
        source_url,
        data_hash,
        scraped_dt

    from source_data
),

cleaned_data as (
    select
        -- Business attributes
        id,
        spider_name,
        track_name,
        race_date,
        race_number,
        race_time,
        race_distance,
        race_restrictions,
        race_purse,
        race_wager,
        race_report,
        purse_amount,
        distance_furlongs,
        surface_type,

        -- Data quality flags
        case when track_name is null or track_name = '' then true else false end as missing_track_name,
        case when race_date is null then true else false end as missing_race_date,
        case when race_number is null then true else false end as missing_race_number,

        -- Metadata (at end)
        source_url,
        data_hash,
        scraped_dt

    from parsed_data
)

select * from cleaned_data
where not (missing_track_name or missing_race_date or missing_race_number)