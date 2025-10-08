{{
  config(
    materialized='table',
    indexes=[
      {'columns': ['trend_date'], 'type': 'btree'},
      {'columns': ['news_source'], 'type': 'btree'},
      {'columns': ['track_name'], 'type': 'btree'}
    ]
  )
}}

-- Daily sentiment trends aggregated by various dimensions
with daily_sentiment as (
    select
        date_trunc('day', published_date) as trend_date,
        news_source,
        enhanced_track_name as track_name,
        category,

        -- Article counts
        count(*) as total_articles,
        count(case when overall_sentiment_label = 'positive' then 1 end) as positive_articles,
        count(case when overall_sentiment_label = 'negative' then 1 end) as negative_articles,
        count(case when overall_sentiment_label = 'neutral' then 1 end) as neutral_articles,

        -- Sentiment scores
        avg(overall_sentiment_score) as avg_sentiment_score,
        avg(basic_sentiment_score) as avg_basic_sentiment,
        avg(racing_sentiment_score) as avg_racing_sentiment,

        -- Text quality metrics
        avg(word_count) as avg_word_count,
        avg(text_quality_score) as avg_text_quality,

        -- Entity metrics (simplified for SQL version)
        avg(racing_terms_count) as avg_racing_terms_per_article,
        avg(case when has_trainer_mention = 1 then 1 else 0 end) as pct_with_trainer_mention,
        avg(case when has_major_track_mention = 1 then 1 else 0 end) as pct_with_track_mention,

        -- Confidence and reliability
        avg(sentiment_confidence) as avg_sentiment_confidence,
        stddev(overall_sentiment_score) as sentiment_volatility

    from {{ ref('fct_news_entities') }}
    where published_date is not null
        and text_quality_score > 0.3  -- Filter for quality articles
    group by 1, 2, 3, 4
),

-- Calculate percentiles and additional metrics
enriched_trends as (
    select
        *,

        -- Sentiment distribution percentages
        round((positive_articles * 100.0 / total_articles), 2) as positive_percentage,
        round((negative_articles * 100.0 / total_articles), 2) as negative_percentage,
        round((neutral_articles * 100.0 / total_articles), 2) as neutral_percentage,

        -- Sentiment intensity classification
        case
            when avg_sentiment_score > 0.3 then 'very_positive'
            when avg_sentiment_score > 0.1 then 'positive'
            when avg_sentiment_score < -0.3 then 'very_negative'
            when avg_sentiment_score < -0.1 then 'negative'
            else 'neutral'
        end as sentiment_intensity,

        -- Volume classification
        case
            when total_articles >= 20 then 'high'
            when total_articles >= 10 then 'medium'
            when total_articles >= 5 then 'low'
            else 'very_low'
        end as volume_category,

        -- Quality indicators
        case
            when avg_text_quality >= 0.8 then 'high_quality'
            when avg_text_quality >= 0.6 then 'medium_quality'
            else 'low_quality'
        end as content_quality_tier

    from daily_sentiment
),

-- Add rolling averages and trends
final as (
    select
        trend_date,
        news_source,
        track_name,
        category,

        -- Core metrics
        total_articles,
        positive_articles,
        negative_articles,
        neutral_articles,

        -- Sentiment scores
        round(avg_sentiment_score, 4) as avg_sentiment_score,
        round(avg_basic_sentiment, 4) as avg_basic_sentiment,
        round(avg_racing_sentiment, 4) as avg_racing_sentiment,

        -- Percentages
        positive_percentage,
        negative_percentage,
        neutral_percentage,

        -- Classifications
        sentiment_intensity,
        volume_category,
        content_quality_tier,

        -- Text and entity metrics
        round(avg_word_count, 0) as avg_word_count,
        round(avg_text_quality, 3) as avg_text_quality,
        round(avg_racing_terms_per_article, 1) as avg_racing_terms_per_article,
        round(pct_with_trainer_mention, 3) as pct_with_trainer_mention,
        round(pct_with_track_mention, 3) as pct_with_track_mention,

        -- Confidence and reliability
        round(avg_sentiment_confidence, 3) as avg_sentiment_confidence,
        round(sentiment_volatility, 4) as sentiment_volatility,

        -- Rolling 7-day averages
        round(avg(avg_sentiment_score) over (
            partition by news_source, track_name
            order by trend_date
            rows between 6 preceding and current row
        ), 4) as sentiment_7day_avg,

        -- Momentum indicators
        case
            when avg_sentiment_score > lag(avg_sentiment_score, 1) over (
                partition by news_source, track_name
                order by trend_date
            ) then 'improving'
            when avg_sentiment_score < lag(avg_sentiment_score, 1) over (
                partition by news_source, track_name
                order by trend_date
            ) then 'declining'
            else 'stable'
        end as sentiment_momentum,

        -- Processing metadata
        current_timestamp as processed_at

    from enriched_trends
)

select * from final
order by trend_date desc, total_articles desc