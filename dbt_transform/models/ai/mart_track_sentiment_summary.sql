{{
  config(
    materialized='table',
    indexes=[
      {'columns': ['track_name'], 'type': 'btree'},
      {'columns': ['sentiment_rank'], 'type': 'btree'}
    ]
  )
}}

-- Track-level sentiment analysis summary for business insights
with track_sentiment_base as (
    select
        enhanced_track_name as track_name,
        enhanced_track_key as track_key,

        -- Article volume metrics
        count(*) as total_articles,
        count(distinct date_trunc('day', published_date)) as days_covered,
        min(published_date) as first_article_date,
        max(published_date) as last_article_date,

        -- Sentiment distribution
        count(case when overall_sentiment_label = 'positive' then 1 end) as positive_articles,
        count(case when overall_sentiment_label = 'negative' then 1 end) as negative_articles,
        count(case when overall_sentiment_label = 'neutral' then 1 end) as neutral_articles,

        -- Average sentiment scores
        avg(overall_sentiment_score) as avg_sentiment_score,
        avg(basic_sentiment_score) as avg_basic_score,
        avg(racing_sentiment_score) as avg_racing_sentiment,

        -- Sentiment score ranges
        min(overall_sentiment_score) as min_sentiment_score,
        max(overall_sentiment_score) as max_sentiment_score,
        stddev(overall_sentiment_score) as sentiment_volatility,

        -- Content quality metrics
        avg(text_quality_score) as avg_content_quality,
        avg(word_count) as avg_article_length,

        -- Entity and racing-specific metrics
        avg(racing_terms_count) as avg_racing_terms_per_article,
        avg(case when has_trainer_mention = 1 then 1 else 0 end) as avg_trainer_mentions,
        avg(case when has_major_track_mention = 1 then 1 else 0 end) as avg_track_mentions,
        avg(sentiment_confidence) as avg_sentiment_confidence,

        -- Recent vs historical comparison
        avg(case when published_date >= current_date - interval '30 days'
            then overall_sentiment_score end) as recent_30d_sentiment,
        avg(case when published_date >= current_date - interval '7 days'
            then overall_sentiment_score end) as recent_7d_sentiment,

        count(case when published_date >= current_date - interval '30 days' then 1 end) as recent_30d_articles,
        count(case when published_date >= current_date - interval '7 days' then 1 end) as recent_7d_articles

    from {{ ref('fct_news_entities') }}
    where enhanced_track_name is not null
        and text_quality_score > 0.3
        and published_date >= current_date - interval '1 year'  -- Focus on last year
    group by enhanced_track_name, enhanced_track_key
    having count(*) >= 5  -- Only tracks with meaningful coverage
),

-- Calculate rankings and percentiles
ranked_tracks as (
    select
        *,

        -- Sentiment percentages
        round((positive_articles * 100.0 / total_articles), 2) as positive_percentage,
        round((negative_articles * 100.0 / total_articles), 2) as negative_percentage,
        round((neutral_articles * 100.0 / total_articles), 2) as neutral_percentage,

        -- Coverage metrics
        round(total_articles::decimal / days_covered, 2) as articles_per_day,

        -- Sentiment momentum
        case
            when recent_7d_sentiment > recent_30d_sentiment + 0.1 then 'strongly_improving'
            when recent_7d_sentiment > recent_30d_sentiment + 0.05 then 'improving'
            when recent_7d_sentiment < recent_30d_sentiment - 0.1 then 'strongly_declining'
            when recent_7d_sentiment < recent_30d_sentiment - 0.05 then 'declining'
            else 'stable'
        end as sentiment_trend,

        -- Overall track sentiment classification
        case
            when avg_sentiment_score > 0.2 then 'very_positive'
            when avg_sentiment_score > 0.05 then 'positive'
            when avg_sentiment_score < -0.2 then 'very_negative'
            when avg_sentiment_score < -0.05 then 'negative'
            else 'neutral'
        end as overall_sentiment_category,

        -- Coverage quality assessment
        case
            when avg_content_quality >= 0.8 and total_articles >= 50 then 'excellent_coverage'
            when avg_content_quality >= 0.7 and total_articles >= 20 then 'good_coverage'
            when avg_content_quality >= 0.6 and total_articles >= 10 then 'fair_coverage'
            else 'limited_coverage'
        end as coverage_assessment,

        -- Rankings
        rank() over (order by avg_sentiment_score desc) as sentiment_rank,
        rank() over (order by total_articles desc) as volume_rank,
        rank() over (order by avg_content_quality desc) as quality_rank,

        -- Percentiles
        ntile(4) over (order by avg_sentiment_score) as sentiment_quartile,
        ntile(4) over (order by total_articles) as volume_quartile

    from track_sentiment_base
),

-- Final summary with additional insights
final as (
    select
        track_name,
        track_key,

        -- Core metrics
        total_articles,
        days_covered,
        first_article_date,
        last_article_date,

        -- Sentiment summary
        round(avg_sentiment_score, 4) as avg_sentiment_score,
        overall_sentiment_category,
        sentiment_rank,
        sentiment_quartile,

        -- Distribution
        positive_articles,
        negative_articles,
        neutral_articles,
        positive_percentage,
        negative_percentage,
        neutral_percentage,

        -- Detailed sentiment scores
        round(avg_basic_score, 4) as avg_basic_score,
        round(avg_racing_sentiment, 4) as avg_racing_sentiment,

        -- Volatility and ranges
        round(sentiment_volatility, 4) as sentiment_volatility,
        round(min_sentiment_score, 4) as min_sentiment_score,
        round(max_sentiment_score, 4) as max_sentiment_score,

        -- Recent trends
        round(recent_30d_sentiment, 4) as recent_30d_sentiment,
        round(recent_7d_sentiment, 4) as recent_7d_sentiment,
        recent_30d_articles,
        recent_7d_articles,
        sentiment_trend,

        -- Coverage metrics
        round(articles_per_day, 2) as articles_per_day,
        volume_rank,
        volume_quartile,
        coverage_assessment,

        -- Content quality
        round(avg_content_quality, 3) as avg_content_quality,
        round(avg_article_length, 0) as avg_article_length,
        quality_rank,

        -- Racing-specific insights
        round(avg_racing_terms_per_article, 1) as avg_racing_terms_per_article,
        round(avg_trainer_mentions, 3) as avg_trainer_mentions,
        round(avg_track_mentions, 3) as avg_track_mentions,
        round(avg_sentiment_confidence, 3) as avg_sentiment_confidence,

        -- Business insights
        case
            when sentiment_rank <= 5 and volume_rank <= 10 then 'high_positive_visibility'
            when sentiment_rank >= (select count(*) from ranked_tracks) - 5 then 'reputation_risk'
            when volume_rank <= 5 then 'high_media_attention'
            when total_articles < 10 then 'low_visibility'
            else 'normal_coverage'
        end as business_insight,

        -- Processing metadata
        current_timestamp as processed_at

    from ranked_tracks
)

select * from final
order by sentiment_rank, volume_rank