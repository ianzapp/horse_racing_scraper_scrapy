{{ config(materialized='view') }}

WITH cleaned_news AS (
    SELECT
        id,
        spider_name,
        source_url,
        crawl_run_id,
        data_hash,
        created_at,

        -- Create business key for deduplication
        {{ dbt_utils.generate_surrogate_key(['source_url', 'data_hash']) }} as business_key,

        -- Extract and clean news fields from JSON
        TRIM(REPLACE(REPLACE(raw_data->>'title', E'\n', ' '), E'\r', '')) as title,
        TRIM(REPLACE(REPLACE(raw_data->>'content', E'\n', ' '), E'\r', '')) as content,
        TRIM(raw_data->>'author') as author,
        TRIM(raw_data->>'category') as category,

        -- Parse date fields (extract from publication_date field)
        CASE
            WHEN raw_data->>'publication_date' IS NOT NULL
            AND raw_data->>'publication_date' != ''
            THEN CAST(raw_data->>'publication_date' AS DATE)
            ELSE NULL
        END as published_date,

        -- Extract metadata
        TRIM(raw_data->>'summary') as summary,
        COALESCE(
            TRIM(raw_data->>'news_source'),
            TRIM(raw_data->>'source')
        ) as news_source,

        -- Tags/keywords if available
        raw_data->>'tags' as tags

    FROM {{ source('public', 'raw_scraped_data') }}
    WHERE item_type = 'news'
        AND raw_data IS NOT NULL
)

SELECT * FROM cleaned_news
WHERE title IS NOT NULL  -- Filter out records without essential data