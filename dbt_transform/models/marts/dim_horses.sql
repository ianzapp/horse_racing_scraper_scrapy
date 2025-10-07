{{
  config(
    materialized='table',
    unique_key='horse_key'
  )
}}

with horse_entries as (
    select
        horse_name,
        sire,
        max(created_at) as last_seen
    from {{ ref('stg_race_entries') }}
    where horse_name is not null
    group by 1, 2
),

horse_results as (
    select
        horse_name,
        null as sire,
        max(created_at) as last_seen
    from {{ ref('stg_race_results') }}
    where horse_name is not null
    group by 1, 2
),

horse_speed_figures as (
    select
        horse_name,
        sire_name as sire,
        hrn_speed_figure,
        power_ranking,
        trainer_name,
        jockey_name,
        career_earnings,
        max(created_at) as last_seen
    from {{ ref('stg_hrn_speed_results') }}
    where horse_name is not null
    group by 1, 2, 3, 4, 5, 6, 7
),

all_horses as (
    select
        horse_name,
        sire,
        null::integer as hrn_speed_figure,
        null::integer as power_ranking,
        null::text as trainer_name,
        null::text as jockey_name,
        null::decimal as career_earnings,
        last_seen
    from horse_entries
    union all
    select
        horse_name,
        sire,
        null::integer as hrn_speed_figure,
        null::integer as power_ranking,
        null::text as trainer_name,
        null::text as jockey_name,
        null::decimal as career_earnings,
        last_seen
    from horse_results
    union all
    select
        horse_name,
        sire,
        hrn_speed_figure,
        power_ranking,
        trainer_name,
        jockey_name,
        career_earnings,
        last_seen
    from horse_speed_figures
),

deduplicated_horses as (
    select
        horse_name,
        -- Take the most complete sire information
        coalesce(
            max(case when sire is not null and sire != '' then sire end),
            max(sire)
        ) as sire,
        -- Take the most recent speed figure and ranking data
        max(hrn_speed_figure) as current_speed_figure,
        max(power_ranking) as current_power_ranking,
        -- Take the most recent connections
        max(case when trainer_name is not null then trainer_name end) as current_trainer,
        max(case when jockey_name is not null then jockey_name end) as current_jockey,
        max(career_earnings) as career_earnings,
        max(last_seen) as last_seen
    from all_horses
    group by horse_name
),

final as (
    select
        {{ dbt_utils.generate_surrogate_key(['horse_name']) }} as horse_key,
        horse_name,
        sire,
        current_speed_figure,
        current_power_ranking,
        current_trainer,
        current_jockey,
        career_earnings,
        last_seen,
        current_timestamp as created_at
    from deduplicated_horses
)

select * from final