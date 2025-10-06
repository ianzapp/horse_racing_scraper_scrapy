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
        source_url,
        raw_data,
        data_hash,
        created_at
    from {{ source('public', 'raw_scraped_data') }}
    where item_type = 'track_info'

    {% if is_incremental() %}
        and created_at > (select max(created_at) from {{ this }})
    {% endif %}
),

parsed_data as (
    select
        id,
        spider_name,
        source_url,
        data_hash,
        created_at,

        -- Extract and clean track information
        trim(raw_data->>'track_name') as track_name,
        (raw_data->>'race_date')::date as race_date,
        trim(raw_data->>'track_location') as track_location,
        trim(raw_data->>'track_description') as track_description,
        raw_data->>'track_website' as track_website,

        -- Extract state/country from location if possible
        case
            when raw_data->>'track_location' ~ ', [A-Z]{2}$' then
                trim(split_part(raw_data->>'track_location', ',', -1))
            else null
        end as track_state,

        case
            when raw_data->>'track_location' ~ ', [A-Z]{2}$' then
                trim(regexp_replace(raw_data->>'track_location', ', [A-Z]{2}$', ''))
            else trim(raw_data->>'track_location')
        end as track_city

    from source_data
),

cleaned_data as (
    select
        *,
        -- Create business key
        concat(track_name, '|', race_date) as business_key,

        -- Data quality flags
        case when track_name is null or track_name = '' then true else false end as missing_track_name

    from parsed_data
)

select * from cleaned_data
where not missing_track_name