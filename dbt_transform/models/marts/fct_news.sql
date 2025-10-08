{{
  config(
    materialized='table',
    unique_key='news_key'
  )
}}

with news_data as (
    select
        n.*
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

        -- Metadata
        business_key,
        source_url,
        crawl_run_id,
        created_at

    from news_data
    where title is not null  -- Only include articles with content
)

select * from final