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
    where item_type = 'news'

    {% if is_incremental() %}
        and created_at > (select max(scraped_dt) from {{ this }})
    {% endif %}
),

cleaned_news AS (
    SELECT
        id,
        spider_name,

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
        raw_data->>'tags' as tags,

        -- Metadata (at end)
        source_url,
        data_hash,
        scraped_dt

    FROM source_data
)

SELECT * FROM cleaned_news
WHERE title IS NOT NULL  -- Filter out records without essential data