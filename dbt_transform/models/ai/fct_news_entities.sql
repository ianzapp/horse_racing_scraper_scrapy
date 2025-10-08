{{
  config(
    materialized='table',
    indexes=[
      {'columns': ['news_key'], 'type': 'btree'},
      {'columns': ['published_date'], 'type': 'btree'}
    ]
  )
}}

-- Enhanced news with entity extraction using SQL pattern matching
with sentiment_news as (
    select * from {{ ref('fct_news_with_sentiment') }}
),

-- Extract entities using regex and pattern matching
entity_extraction as (
    select
        *,

        -- Extract horse names (simplified pattern matching)
        array_to_string(
            regexp_split_to_array(
                regexp_replace(
                    content,
                    '.*(horse|colt|filly|mare|gelding)\s+([A-Z][a-z]+(?:\s[A-Z][a-z]+){0,2}).*',
                    '\2',
                    'gi'
                ),
                '\s+'
            ),
            ', '
        ) as extracted_horse_names,

        -- Count entity mentions
        (select count(*)
         from regexp_split_to_table(content, '\s+') as word
         where word ~ '^[A-Z][a-z]+$'
         and length(word) > 3) as capitalized_words_count,

        -- Track name extraction
        case
            when lower(content) ~ 'churchill\s+downs?' then 'Churchill Downs'
            when lower(content) ~ 'keeneland' then 'Keeneland'
            when lower(content) ~ 'belmont\s+park?' then 'Belmont Park'
            when lower(content) ~ 'saratoga' then 'Saratoga'
            when lower(content) ~ 'del\s+mar' then 'Del Mar'
            when lower(content) ~ 'santa\s+anita' then 'Santa Anita'
            when lower(content) ~ 'gulfstream' then 'Gulfstream Park'
            when lower(content) ~ 'oaklawn' then 'Oaklawn Park'
            when lower(content) ~ 'fair\s+grounds?' then 'Fair Grounds'
            when lower(content) ~ 'aqueduct' then 'Aqueduct'
            else null
        end as extracted_track_name,

        -- Race type extraction
        case
            when lower(content) ~ 'grade\s+1|grade\s+i\b' then 'Grade 1'
            when lower(content) ~ 'grade\s+2|grade\s+ii\b' then 'Grade 2'
            when lower(content) ~ 'grade\s+3|grade\s+iii\b' then 'Grade 3'
            when lower(content) ~ 'stakes' then 'Stakes'
            when lower(content) ~ 'handicap' then 'Handicap'
            when lower(content) ~ 'allowance' then 'Allowance'
            when lower(content) ~ 'maiden' then 'Maiden'
            when lower(content) ~ 'claiming' then 'Claiming'
            else null
        end as extracted_race_type,

        -- Stakes race extraction
        case
            when lower(content) ~ 'kentucky\s+derby' then 'Kentucky Derby'
            when lower(content) ~ 'preakness\s+stakes' then 'Preakness Stakes'
            when lower(content) ~ 'belmont\s+stakes' then 'Belmont Stakes'
            when lower(content) ~ 'breeders.?\s+cup' then 'Breeders Cup'
            when lower(content) ~ 'dubai\s+world\s+cup' then 'Dubai World Cup'
            when lower(content) ~ 'santa\s+anita\s+derby' then 'Santa Anita Derby'
            when lower(content) ~ 'florida\s+derby' then 'Florida Derby'
            when lower(content) ~ 'arkansas\s+derby' then 'Arkansas Derby'
            when lower(content) ~ 'wood\s+memorial' then 'Wood Memorial'
            when lower(content) ~ 'blue\s+grass\s+stakes' then 'Blue Grass Stakes'
            else null
        end as extracted_stakes_race,

        -- Distance extraction
        case
            when content ~ '\d+\s+furlong' then
                substring(content from '\d+(?=\s+furlong)')
            when content ~ '\d+\.\d+\s+mile' then
                substring(content from '\d+\.\d+(?=\s+mile)')
            when content ~ '\d+\s+mile' then
                substring(content from '\d+(?=\s+mile)')
            else null
        end as extracted_distance,

        -- Surface extraction
        case
            when lower(content) ~ '\bdirt\b' then 'Dirt'
            when lower(content) ~ '\bturf\b|\bgrass\b' then 'Turf'
            when lower(content) ~ 'synthetic|polytrack|tapeta' then 'Synthetic'
            when lower(content) ~ 'all\s+weather' then 'All Weather'
            else null
        end as extracted_surface,

        -- Racing connections extraction indicators
        case when content ~ '(trainer?|trained by)' then 1 else 0 end as has_trainer_reference,
        case when content ~ '(jockey|ridden by|rider)' then 1 else 0 end as has_jockey_reference,
        case when content ~ '(owner|owned by)' then 1 else 0 end as has_owner_reference,
        case when content ~ '(breeder|bred by)' then 1 else 0 end as has_breeder_reference,

        -- Racing terminology count
        (
            case when lower(content) like '%furlong%' then 1 else 0 end +
            case when lower(content) like '%length%' then 1 else 0 end +
            case when lower(content) like '%nose%' then 1 else 0 end +
            case when lower(content) like '%head%' then 1 else 0 end +
            case when lower(content) like '%neck%' then 1 else 0 end +
            case when lower(content) like '%photo finish%' then 1 else 0 end +
            case when lower(content) like '%wire%' then 1 else 0 end +
            case when lower(content) like '%stretch%' then 1 else 0 end +
            case when lower(content) like '%gate%' then 1 else 0 end +
            case when lower(content) like '%odds%' then 1 else 0 end +
            case when lower(content) like '%favorite%' then 1 else 0 end +
            case when lower(content) like '%longshot%' then 1 else 0 end +
            case when lower(content) like '%exacta%' then 1 else 0 end +
            case when lower(content) like '%trifecta%' then 1 else 0 end +
            case when lower(content) like '%superfecta%' then 1 else 0 end +
            case when lower(content) like '%purse%' then 1 else 0 end +
            case when lower(content) like '%earnings%' then 1 else 0 end +
            case when lower(content) like '%sire%' then 1 else 0 end +
            case when lower(content) like '%dam%' then 1 else 0 end +
            case when lower(content) like '%bloodstock%' then 1 else 0 end
        ) as racing_terminology_count

    from sentiment_news
),

-- Enhanced track association with proper JOIN
enhanced_tracks as (
    select
        ee.*,
        dt_extracted.track_key as extracted_track_key
    from entity_extraction ee
    left join {{ ref('dim_tracks') }} dt_extracted
        on ee.extracted_track_name = dt_extracted.track_name
),

-- Final entity metrics calculation
final_entities as (
    select
        *,

        -- Enhanced track name (uses extracted track name from content analysis)
        extracted_track_name as enhanced_track_name,

        -- Enhanced track key lookup (uses extracted track key)
        extracted_track_key as enhanced_track_key,

        -- Total entity indicators count
        (
            case when extracted_track_name is not null then 1 else 0 end +
            case when extracted_race_type is not null then 1 else 0 end +
            case when extracted_stakes_race is not null then 1 else 0 end +
            case when extracted_distance is not null then 1 else 0 end +
            case when extracted_surface is not null then 1 else 0 end +
            has_trainer_reference +
            has_jockey_reference +
            has_owner_reference +
            has_breeder_reference +
            least(racing_terminology_count, 5)  -- Cap at 5 for scoring
        ) as total_entities_count,

        -- Entity density (entities per 100 words)
        case
            when word_count > 0 then
                (
                    case when extracted_track_name is not null then 1 else 0 end +
                    case when extracted_race_type is not null then 1 else 0 end +
                    case when extracted_stakes_race is not null then 1 else 0 end +
                    racing_terminology_count
                ) * 100.0 / word_count
            else 0.0
        end as entity_density,

        -- Racing relevance score
        case
            when racing_terminology_count = 0 then 0.0
            else least(1.0,
                (racing_terminology_count * 0.1 +
                 case when extracted_race_type is not null then 0.2 else 0 end +
                 case when extracted_stakes_race is not null then 0.3 else 0 end +
                 case when extracted_track_name is not null then 0.2 else 0 end +
                 (has_trainer_reference + has_jockey_reference) * 0.1)
            )
        end as racing_relevance_score,

        current_timestamp as entities_processed_at

    from enhanced_tracks
)

select * from final_entities