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
    where item_type = 'race_result'

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

        -- Basic race information
        trim(raw_data->>'track_name') as track_name,
        (raw_data->>'race_date')::date as race_date,
        (raw_data->>'race_number')::integer as race_number,
        trim(raw_data->>'horse_name') as horse_name,
        (raw_data->>'finish_position')::integer as finish_position,

        -- Payout information
        trim(raw_data->>'win_payout') as win_payout_raw,
        trim(raw_data->>'place_payout') as place_payout_raw,
        trim(raw_data->>'show_payout') as show_payout_raw,

        -- Convert payouts to decimal (remove $ and convert)
        case
            when raw_data->>'win_payout' is not null
                and raw_data->>'win_payout' != ''
                and raw_data->>'win_payout' != '-'
            then regexp_replace(raw_data->>'win_payout', '[^0-9.]', '', 'g')::numeric
            else null
        end as win_payout,

        case
            when raw_data->>'place_payout' is not null
                and raw_data->>'place_payout' != ''
                and raw_data->>'place_payout' != '-'
            then regexp_replace(raw_data->>'place_payout', '[^0-9.]', '', 'g')::numeric
            else null
        end as place_payout,

        case
            when raw_data->>'show_payout' is not null
                and raw_data->>'show_payout' != ''
                and raw_data->>'show_payout' != '-'
            then regexp_replace(raw_data->>'show_payout', '[^0-9.]', '', 'g')::numeric
            else null
        end as show_payout

    from source_data
),

cleaned_data as (
    select
        *,
        -- Business key
        concat(track_name, '|', race_date, '|', race_number, '|', horse_name) as business_key,

        -- Derived fields
        case when finish_position = 1 then true else false end as is_winner,
        case when finish_position <= 3 then true else false end as in_money,

        -- Data quality flags
        case when horse_name is null or horse_name = '' then true else false end as missing_horse_name,
        case when track_name is null or track_name = '' then true else false end as missing_track_name,
        case when race_date is null then true else false end as missing_race_date,
        case when finish_position is null then true else false end as missing_finish_position

    from parsed_data
)

select * from cleaned_data
where not (missing_horse_name or missing_track_name or missing_race_date or missing_finish_position)