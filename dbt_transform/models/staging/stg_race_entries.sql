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
    where item_type = 'race_entry'

    {% if is_incremental() %}
        -- Only process new records since last run
        and created_at > (select max(scraped_dt) from {{ this }})
    {% endif %}
),

parsed_data as (
    select
        id,
        spider_name,

        -- Extract fields from JSON with proper typing and cleaning
        trim(raw_data->>'track_name') as track_name,
        (raw_data->>'race_date')::date as race_date,
        (raw_data->>'race_number')::integer as race_number,
        trim(raw_data->>'horse_name') as horse_name,

        -- Handle post_position - some might be strings like "1A"
        case
            when raw_data->>'post_position' ~ '^[0-9]+$'
            then (raw_data->>'post_position')::integer
            else null
        end as post_position,

        -- Speed figure as integer, handle nulls
        case
            when raw_data->>'speed_figure' is not null
                and raw_data->>'speed_figure' != ''
                and raw_data->>'speed_figure' ~ '^[0-9]+$'
            then (raw_data->>'speed_figure')::integer
            else null
        end as speed_figure,

        trim(raw_data->>'sire') as sire,
        trim(raw_data->>'trainer') as trainer,
        trim(raw_data->>'jockey') as jockey,
        trim(raw_data->>'odds') as odds,

        -- Extract numerical odds for analysis
        case
            when raw_data->>'odds' ~ '^[0-9]+/[0-9]+$' then
                split_part(raw_data->>'odds', '/', 1)::numeric /
                split_part(raw_data->>'odds', '/', 2)::numeric
            when raw_data->>'odds' ~ '^[0-9]+\.[0-9]+$' then
                (raw_data->>'odds')::numeric
            else null
        end as odds_decimal,

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
        horse_name,
        post_position,
        speed_figure,
        sire,
        trainer,
        jockey,
        odds,
        odds_decimal,

        -- Data quality flags
        case when horse_name is null or horse_name = '' then true else false end as missing_horse_name,
        case when track_name is null or track_name = '' then true else false end as missing_track_name,
        case when race_date is null then true else false end as missing_race_date,

        -- Metadata (at end)
        source_url,
        data_hash,
        scraped_dt

    from parsed_data
)

select * from cleaned_data

-- Only include records with minimum required data
where not (missing_horse_name or missing_track_name or missing_race_date)