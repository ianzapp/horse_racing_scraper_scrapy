{{
  config(
    materialized='table',
    unique_key='entry_key'
  )
}}

with race_entries as (
    select * from {{ ref('stg_race_entries') }}
),

races as (
    select * from {{ ref('fct_races') }}
),

horses as (
    select * from {{ ref('dim_horses') }}
),

trainers as (
    select * from {{ ref('dim_trainers') }}
),

jockeys as (
    select * from {{ ref('dim_jockeys') }}
),

entry_details as (
    select
        re.*,
        r.race_key,
        h.horse_key,
        h.current_owner_key as owner_key,
        h.current_owner as owner_name,
        t.trainer_key,
        j.jockey_key
    from race_entries re
    left join races r on re.track_name = r.track_name
        and re.race_date = r.race_date
        and re.race_number = r.race_number
    left join horses h on re.horse_name = h.horse_name
    left join trainers t on re.trainer = t.trainer_name
    left join jockeys j on re.jockey = j.jockey_name
),

final as (
    select
        {{ dbt_utils.generate_surrogate_key(['track_name', 'race_date', 'race_number', 'horse_name']) }} as entry_key,

        -- Foreign keys
        race_key,
        horse_key,
        trainer_key,
        jockey_key,
        owner_key,

        -- Natural keys / Frequently filtered dimensions
        track_name,
        race_date,
        race_number,
        horse_name,

        -- Human-readable names (for display)
        trainer,
        jockey,
        owner_name,

        -- Measures (the actual facts)
        post_position,
        speed_figure,
        odds,
        odds_decimal,

        -- Metadata / Lineage
        id as staging_id,
        data_hash,
        scraped_dt
    from entry_details
)

select * from final