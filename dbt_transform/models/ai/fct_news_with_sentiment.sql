{{
  config(
    materialized='table',
    indexes=[
      {'columns': ['news_key'], 'type': 'btree'},
      {'columns': ['published_date'], 'type': 'btree'},
      {'columns': ['overall_sentiment_label'], 'type': 'btree'}
    ]
  )
}}

-- Enhanced news fact table with SQL-based sentiment analysis
with base_news as (
    select * from {{ ref('fct_news') }}
),

-- Text preprocessing and quality metrics
text_metrics as (
    select
        news_key,

        -- Clean content for analysis
        {{ clean_text_for_sentiment('content') }} as cleaned_content,
        {{ clean_text_for_sentiment('title') }} as cleaned_title,

        -- Text quality assessment
        case
            when content is null or trim(content) = '' then false
            else {{ is_quality_text('content') }}
        end as is_quality_content,

        -- Basic text metrics
        case
            when content is not null then
                array_length(string_to_array(trim(content), ' '), 1)
            else 0
        end as word_count,

        case
            when content is not null then
                length(trim(content))
            else 0
        end as char_count,

        case
            when content is not null and array_length(string_to_array(trim(content), ' '), 1) > 0 then
                length(trim(content))::decimal / array_length(string_to_array(trim(content), ' '), 1)
            else 0.0
        end as avg_word_length,

        -- Sentence count estimation
        case
            when content is not null then
                array_length(string_to_array(content, '.'), 1)
            else 0
        end as sentence_count
    from base_news
),

-- Simple sentiment analysis using keyword matching
sentiment_analysis as (
    select
        tm.*,

        -- Positive sentiment indicators
        (
            length(cleaned_content) - length(replace(lower(cleaned_content), 'win', ''))
        ) / 3 +
        (
            length(cleaned_content) - length(replace(lower(cleaned_content), 'victory', ''))
        ) / 7 +
        (
            length(cleaned_content) - length(replace(lower(cleaned_content), 'champion', ''))
        ) / 8 +
        (
            length(cleaned_content) - length(replace(lower(cleaned_content), 'excellent', ''))
        ) / 9 +
        (
            length(cleaned_content) - length(replace(lower(cleaned_content), 'outstanding', ''))
        ) / 11 as positive_indicators,

        -- Negative sentiment indicators
        (
            length(cleaned_content) - length(replace(lower(cleaned_content), 'injury', ''))
        ) / 6 +
        (
            length(cleaned_content) - length(replace(lower(cleaned_content), 'failed', ''))
        ) / 6 +
        (
            length(cleaned_content) - length(replace(lower(cleaned_content), 'disappointing', ''))
        ) / 13 +
        (
            length(cleaned_content) - length(replace(lower(cleaned_content), 'poor', ''))
        ) / 4 +
        (
            length(cleaned_content) - length(replace(lower(cleaned_content), 'struggled', ''))
        ) / 9 as negative_indicators,

        -- Racing-specific positive terms
        case when lower(cleaned_content) like '%stakes%' then 1 else 0 end +
        case when lower(cleaned_content) like '%grade 1%' then 2 else 0 end +
        case when lower(cleaned_content) like '%grade 2%' then 1 else 0 end +
        case when lower(cleaned_content) like '%grade 3%' then 1 else 0 end +
        case when lower(cleaned_content) like '%favorite%' then 1 else 0 end +
        case when lower(cleaned_content) like '%record%' then 1 else 0 end as racing_positive_score,

        -- Racing-specific negative terms
        case when lower(cleaned_content) like '%scratch%' then 1 else 0 end +
        case when lower(cleaned_content) like '%pulled up%' then 2 else 0 end +
        case when lower(cleaned_content) like '%fall%' then 2 else 0 end +
        case when lower(cleaned_content) like '%breakdown%' then 3 else 0 end +
        case when lower(cleaned_content) like '%retirement%' then 2 else 0 end +
        case when lower(cleaned_content) like '%suspended%' then 2 else 0 end as racing_negative_score

    from text_metrics tm
    where is_quality_content = true
),

-- Calculate sentiment scores and classifications
sentiment_scores as (
    select
        *,

        -- Basic sentiment score calculation
        case
            when positive_indicators + negative_indicators = 0 then 0.0
            else (positive_indicators - negative_indicators)::decimal /
                 greatest(positive_indicators + negative_indicators, 1)
        end as basic_sentiment_score,

        -- Racing-specific sentiment score
        case
            when racing_positive_score + racing_negative_score = 0 then 0.0
            else (racing_positive_score - racing_negative_score)::decimal /
                 greatest(racing_positive_score + racing_negative_score, 1)
        end as racing_sentiment_score,

        -- Text quality score
        case
            when word_count = 0 then 0.0
            else least(1.0,
                (word_count::decimal / 100.0) * 0.4 +
                case when avg_word_length between 3 and 8 then 0.3 else 0.15 end +
                case when sentence_count > 1 then 0.3 else 0.15 end
            )
        end as text_quality_score

    from sentiment_analysis
),

-- Final sentiment calculation and classification
final_sentiment as (
    select
        *,

        -- Overall sentiment score (weighted average)
        (basic_sentiment_score * 0.6 + racing_sentiment_score * 0.4) as overall_sentiment_score,

        -- Sentiment confidence based on text length and indicators
        least(1.0,
            (positive_indicators + negative_indicators + racing_positive_score + racing_negative_score)::decimal / 10.0
        ) as sentiment_confidence

    from sentiment_scores
),

-- Add sentiment labels and entity extraction
enriched_news as (
    select
        fs.*,

        -- Sentiment classification
        case
            when overall_sentiment_score > 0.2 then 'positive'
            when overall_sentiment_score < -0.2 then 'negative'
            else 'neutral'
        end as overall_sentiment_label,

        case
            when basic_sentiment_score > 0.1 then 'positive'
            when basic_sentiment_score < -0.1 then 'negative'
            else 'neutral'
        end as basic_sentiment_label,

        case
            when racing_sentiment_score > 0.1 then 'positive'
            when racing_sentiment_score < -0.1 then 'negative'
            else 'neutral'
        end as racing_sentiment_label,

        -- Simple entity extraction using pattern matching
        case when lower(cleaned_content) ~ '\y(trainer|trained by)\s+([A-Z][a-z]+\s[A-Z][a-z]+)'
             then 1 else 0 end as has_trainer_mention,

        case when lower(cleaned_content) ~ '\y(jockey|ridden by|rider)\s+([A-Z][a-z]+\s[A-Z][a-z]+)'
             then 1 else 0 end as has_jockey_mention,

        case when lower(cleaned_content) ~ '\y(churchill|keeneland|belmont|saratoga|del mar|santa anita|gulfstream)'
             then 1 else 0 end as has_major_track_mention,

        -- Count racing terms
        (case when lower(cleaned_content) like '%furlong%' then 1 else 0 end +
         case when lower(cleaned_content) like '%length%' then 1 else 0 end +
         case when lower(cleaned_content) like '%odds%' then 1 else 0 end +
         case when lower(cleaned_content) like '%purse%' then 1 else 0 end +
         case when lower(cleaned_content) like '%breeder%' then 1 else 0 end) as racing_terms_count,

        current_timestamp as sentiment_processed_at

    from final_sentiment fs
)

-- Final result combining original news data with sentiment analysis
select
    bn.*,

    -- Sentiment scores
    round(en.overall_sentiment_score, 4) as overall_sentiment_score,
    round(en.basic_sentiment_score, 4) as basic_sentiment_score,
    round(en.racing_sentiment_score, 4) as racing_sentiment_score,

    -- Sentiment labels
    en.overall_sentiment_label,
    en.basic_sentiment_label,
    en.racing_sentiment_label,

    -- Text metrics
    en.word_count,
    en.char_count,
    en.sentence_count,
    round(en.avg_word_length, 2) as avg_word_length,
    round(en.text_quality_score, 3) as text_quality_score,

    -- Entity indicators
    en.has_trainer_mention,
    en.has_jockey_mention,
    en.has_major_track_mention,
    en.racing_terms_count,

    -- Confidence and metadata
    round(en.sentiment_confidence, 3) as sentiment_confidence,
    en.is_quality_content,
    en.sentiment_processed_at

from base_news bn
left join enriched_news en on bn.news_key = en.news_key