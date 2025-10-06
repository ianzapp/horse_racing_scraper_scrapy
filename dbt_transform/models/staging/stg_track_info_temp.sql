-- Temporary direct reference version for testing
with source_data as (
    select
        id,
        spider_name,
        source_url,
        raw_data,
        data_hash,
        created_at
    from raw_scraped_data  -- Direct table reference
    where item_type = 'track_info'
),

parsed_data as (
    select
        id,
        spider_name,
        source_url,
        data_hash,
        created_at,

        trim(raw_data->>'track_name') as track_name,
        (raw_data->>'race_date')::date as race_date,
        trim(raw_data->>'track_location') as track_location

    from source_data
    limit 10  -- Just test with 10 records
)

select * from parsed_data