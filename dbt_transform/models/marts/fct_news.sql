{{
  config(
    materialized='table',
    unique_key='news_key'
  )
}}

with news_data as (
    select
        n.*,
        t.track_key,
        -- Create race key if article is related to a specific race
        case
            when n.related_track is not null and n.related_race_date is not null
            then {{ dbt_utils.generate_surrogate_key(['t.track_key', 'n.related_race_date']) }}
            else null
        end as related_race_key
    from {{ ref('stg_news') }} n
    left join {{ ref('dim_tracks') }} t
        on n.related_track = t.track_name
),

final as (
    select
        {{ dbt_utils.generate_surrogate_key(['business_key']) }} as news_key,
        related_race_key,
        track_key,

        -- Article content
        title,
        content,
        summary,
        author,
        category,
        news_source,

        -- Date information
        published_date,
        related_race_date,

        -- URLs and metadata
        article_url,
        image_url,
        tags,

        -- Related race information
        related_track,

        -- Metadata
        business_key,
        source_url,
        crawl_run_id,
        created_at

    from news_data
    where title is not null  -- Only include articles with content
)

select * from final