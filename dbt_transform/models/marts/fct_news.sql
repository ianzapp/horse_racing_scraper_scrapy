{{
  config(
    materialized='table',
    unique_key='news_key'
  )
}}

with news_data as (
    select
        n.*,
        {{ dbt_utils.generate_surrogate_key(['source_url', 'data_hash']) }} as business_key
    from {{ ref('stg_news') }} n
),

final as (
    select
        {{ dbt_utils.generate_surrogate_key(['business_key']) }} as news_key,

        -- Article content
        title,
        content,
        summary,
        author,
        category,
        news_source,

        -- Date information
        published_date,

        -- URLs and metadata
        source_url as article_url,
        tags,

        -- Metadata / Lineage
        id as staging_id,
        data_hash,
        scraped_dt

    from news_data
    where title is not null  -- Only include articles with content
)

select * from final