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
        race_key,
        horse_key,
        trainer_key,
        jockey_key,
        track_name,
        race_date,
        race_number,
        horse_name,
        post_position,
        speed_figure,
        sire,
        trainer,
        jockey,
        odds,
        odds_decimal,
        source_url,
        created_at as scraped_at
    from entry_details
)

select * from final