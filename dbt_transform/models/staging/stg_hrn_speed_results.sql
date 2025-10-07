{{ config(materialized='view') }}

WITH cleaned_speed_results AS (
    SELECT
        id,
        spider_name,
        source_url,
        crawl_run_id,
        data_hash,
        created_at,

        -- Create business key for deduplication
        {{ dbt_utils.generate_surrogate_key(['source_url', 'data_hash']) }} as business_key,

        -- Extract horse and race information
        TRIM(REPLACE(REPLACE(raw_data->>'horse_name', E'\n', ' '), E'\r', '')) as horse_name,
        TRIM(raw_data->>'track_name') as track_name,

        CASE
            WHEN raw_data->>'race_date' IS NOT NULL
            AND raw_data->>'race_date' != ''
            THEN CAST(raw_data->>'race_date' AS DATE)
            ELSE NULL
        END as race_date,

        CASE
            WHEN raw_data->>'race_number' IS NOT NULL
            AND raw_data->>'race_number' ~ '^[0-9]+$'
            THEN CAST(raw_data->>'race_number' AS INTEGER)
            ELSE NULL
        END as race_number,

        -- HRN Speed Figure (main metric)
        CASE
            WHEN raw_data->>'hrn_speed_figure' IS NOT NULL
            AND raw_data->>'hrn_speed_figure' ~ '^[0-9]+$'
            THEN CAST(raw_data->>'hrn_speed_figure' AS INTEGER)
            WHEN raw_data->>'speed_figure' IS NOT NULL
            AND raw_data->>'speed_figure' ~ '^[0-9]+$'
            THEN CAST(raw_data->>'speed_figure' AS INTEGER)
            ELSE NULL
        END as hrn_speed_figure,

        -- Power ranking if this is power rankings data
        CASE
            WHEN raw_data->>'power_ranking' IS NOT NULL
            AND raw_data->>'power_ranking' ~ '^[0-9]+$'
            THEN CAST(raw_data->>'power_ranking' AS INTEGER)
            WHEN raw_data->>'ranking' IS NOT NULL
            AND raw_data->>'ranking' ~ '^[0-9]+$'
            THEN CAST(raw_data->>'ranking' AS INTEGER)
            ELSE NULL
        END as power_ranking,

        -- Horse details
        TRIM(raw_data->>'jockey') as jockey_name,
        TRIM(raw_data->>'trainer') as trainer_name,
        TRIM(raw_data->>'owner') as owner_name,
        TRIM(raw_data->>'sire') as sire_name,

        -- Performance metrics
        CASE
            WHEN raw_data->>'last_race_speed' IS NOT NULL
            AND raw_data->>'last_race_speed' ~ '^[0-9]+$'
            THEN CAST(raw_data->>'last_race_speed' AS INTEGER)
            ELSE NULL
        END as last_race_speed,

        CASE
            WHEN raw_data->>'avg_speed_last_3' IS NOT NULL
            AND raw_data->>'avg_speed_last_3' ~ '^[0-9]*\.?[0-9]+$'
            THEN CAST(raw_data->>'avg_speed_last_3' AS DECIMAL(5,2))
            ELSE NULL
        END as avg_speed_last_3_races,

        -- Race conditions when speed was recorded
        TRIM(raw_data->>'surface') as surface_type,
        TRIM(raw_data->>'distance') as distance,
        TRIM(raw_data->>'race_class') as race_class,

        -- Ranking change indicators
        CASE
            WHEN raw_data->>'ranking_change' IS NOT NULL
            AND raw_data->>'ranking_change' ~ '^[+-]?[0-9]+$'
            THEN CAST(raw_data->>'ranking_change' AS INTEGER)
            ELSE NULL
        END as ranking_change,

        -- Additional metadata
        TRIM(raw_data->>'age') as horse_age,
        TRIM(raw_data->>'sex') as horse_sex,

        CASE
            WHEN raw_data->>'earnings' IS NOT NULL
            AND raw_data->>'earnings' ~ '^[0-9]*\.?[0-9]+$'
            THEN CAST(raw_data->>'earnings' AS DECIMAL(12,2))
            ELSE NULL
        END as career_earnings,

        -- Record details
        TRIM(raw_data->>'record') as race_record,
        TRIM(raw_data->>'last_race_date') as last_race_date_raw

    FROM {{ source('public', 'raw_scraped_data') }}
    WHERE item_type = 'hrn_speed_result'
        AND raw_data IS NOT NULL
)

SELECT * FROM cleaned_speed_results
WHERE horse_name IS NOT NULL  -- Filter out records without essential horse data