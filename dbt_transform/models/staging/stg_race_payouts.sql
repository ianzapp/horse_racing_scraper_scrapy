{{ config(materialized='view') }}

WITH cleaned_payouts AS (
    SELECT
        id,
        spider_name,
        source_url,
        crawl_run_id,
        data_hash,
        created_at,

        -- Create business key for deduplication
        {{ dbt_utils.generate_surrogate_key(['source_url', 'data_hash']) }} as business_key,

        -- Extract and clean basic race information
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

        -- Extract payout information
        CASE
            WHEN raw_data->>'win_payout' IS NOT NULL
            AND raw_data->>'win_payout' ~ '^[0-9]*\.?[0-9]+$'
            THEN CAST(raw_data->>'win_payout' AS DECIMAL(10,2))
            ELSE NULL
        END as win_payout,

        CASE
            WHEN raw_data->>'place_payout' IS NOT NULL
            AND raw_data->>'place_payout' ~ '^[0-9]*\.?[0-9]+$'
            THEN CAST(raw_data->>'place_payout' AS DECIMAL(10,2))
            ELSE NULL
        END as place_payout,

        CASE
            WHEN raw_data->>'show_payout' IS NOT NULL
            AND raw_data->>'show_payout' ~ '^[0-9]*\.?[0-9]+$'
            THEN CAST(raw_data->>'show_payout' AS DECIMAL(10,2))
            ELSE NULL
        END as show_payout,

        -- Exotic bet payouts
        CASE
            WHEN raw_data->>'exacta_payout' IS NOT NULL
            AND raw_data->>'exacta_payout' ~ '^[0-9]*\.?[0-9]+$'
            THEN CAST(raw_data->>'exacta_payout' AS DECIMAL(10,2))
            ELSE NULL
        END as exacta_payout,

        CASE
            WHEN raw_data->>'trifecta_payout' IS NOT NULL
            AND raw_data->>'trifecta_payout' ~ '^[0-9]*\.?[0-9]+$'
            THEN CAST(raw_data->>'trifecta_payout' AS DECIMAL(10,2))
            ELSE NULL
        END as trifecta_payout,

        CASE
            WHEN raw_data->>'superfecta_payout' IS NOT NULL
            AND raw_data->>'superfecta_payout' ~ '^[0-9]*\.?[0-9]+$'
            THEN CAST(raw_data->>'superfecta_payout' AS DECIMAL(10,2))
            ELSE NULL
        END as superfecta_payout,

        -- Winning combinations
        TRIM(raw_data->>'win_horse') as win_horse_name,
        TRIM(raw_data->>'place_horses') as place_horses,
        TRIM(raw_data->>'show_horses') as show_horses,
        TRIM(raw_data->>'exacta_combination') as exacta_combination,
        TRIM(raw_data->>'trifecta_combination') as trifecta_combination,
        TRIM(raw_data->>'superfecta_combination') as superfecta_combination,

        -- Pool and wagering information
        CASE
            WHEN raw_data->>'total_pool' IS NOT NULL
            AND raw_data->>'total_pool' ~ '^[0-9]*\.?[0-9]+$'
            THEN CAST(raw_data->>'total_pool' AS DECIMAL(12,2))
            ELSE NULL
        END as total_pool,

        CASE
            WHEN raw_data->>'win_pool' IS NOT NULL
            AND raw_data->>'win_pool' ~ '^[0-9]*\.?[0-9]+$'
            THEN CAST(raw_data->>'win_pool' AS DECIMAL(12,2))
            ELSE NULL
        END as win_pool

    FROM {{ source('public', 'raw_scraped_data') }}
    WHERE item_type = 'race_payout'
        AND raw_data IS NOT NULL
)

SELECT * FROM cleaned_payouts
WHERE track_name IS NOT NULL
    AND race_date IS NOT NULL
    AND race_number IS NOT NULL  -- Filter out records without essential race identifiers