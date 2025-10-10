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
        max(scraped_dt) as update_dt,
        max(scraped_dt::date) as last_seen_dt
    from {{ ref('stg_race_entries') }}
    where horse_name is not null
    group by 1, 2
),

horse_results as (
    select
        horse_name,
        null as sire,
        max(scraped_dt) as update_dt,
        max(scraped_dt::date) as last_seen_dt
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
        owner_name,
        horse_age,
        horse_sex,
        career_earnings,
        max(scraped_dt) as update_dt,
        max(scraped_dt::date) as last_seen_dt
    from {{ ref('stg_hrn_speed_results') }}
    where horse_name is not null
    group by 1, 2, 3, 4, 5, 6, 7, 8, 9, 10
),

all_horses as (
    select
        horse_name,
        sire,
        null::integer as hrn_speed_figure,
        null::integer as power_ranking,
        null::text as trainer_name,
        null::text as jockey_name,
        null::text as owner_name,
        null::text as horse_age,
        null::text as horse_sex,
        null::decimal as career_earnings,
        update_dt,
        last_seen_dt
    from horse_entries
    union all
    select
        horse_name,
        sire,
        null::integer as hrn_speed_figure,
        null::integer as power_ranking,
        null::text as trainer_name,
        null::text as jockey_name,
        null::text as owner_name,
        null::text as horse_age,
        null::text as horse_sex,
        null::decimal as career_earnings,
        update_dt,
        last_seen_dt
    from horse_results
    union all
    select
        horse_name,
        sire,
        hrn_speed_figure,
        power_ranking,
        trainer_name,
        jockey_name,
        owner_name,
        horse_age,
        horse_sex,
        career_earnings,
        update_dt,
        last_seen_dt
    from horse_speed_figures
),

deduplicated_horses as (
    select
        horse_name,
        -- Take the most complete sire information
        coalesce(
            max(case when sire is not null and sire != '' then sire end),
            max(sire)
        ) as sire_name,
        -- Take the most recent speed figure and ranking data
        max(hrn_speed_figure) as current_speed_figure,
        max(power_ranking) as current_power_ranking,
        -- Take the most recent connections
        max(case when trainer_name is not null then trainer_name end) as current_trainer,
        max(case when jockey_name is not null then jockey_name end) as current_jockey,
        max(case when owner_name is not null then owner_name end) as current_owner,
        -- Take the most recent horse attributes
        max(case when horse_age is not null then horse_age end) as age,
        max(case when horse_sex is not null then horse_sex end) as sex,
        max(career_earnings) as career_earnings,
        max(update_dt) as update_dt,
        max(last_seen_dt) as last_seen_dt
    from all_horses
    group by horse_name
),

horses_with_keys as (
    select
        {{ dbt_utils.generate_surrogate_key(['horse_name']) }} as horse_key,
        horse_name,
        sire_name,
        current_speed_figure,
        current_power_ranking,
        current_trainer,
        current_jockey,
        current_owner,
        age,
        sex,
        career_earnings,
        update_dt,
        last_seen_dt
    from deduplicated_horses
),

with_lineage as (
    select
        h.horse_key,
        h.horse_name,
        h.sire_name,
        h.current_speed_figure,
        h.current_power_ranking,
        h.current_trainer,
        h.current_jockey,
        h.current_owner,
        h.age,
        h.sex,
        h.career_earnings,
        h.update_dt,
        h.last_seen_dt,
        -- Self-referencing FK to sire (if sire exists in dim_horses)
        sire.horse_key as sire_key,
        -- Dam fields (placeholder for future implementation)
        null::text as dam_name,
        null::text as dam_key,
        -- Lookup current trainer, jockey, and owner keys
        t.trainer_key as current_trainer_key,
        j.jockey_key as current_jockey_key,
        o.owner_key as current_owner_key
    from horses_with_keys h
    left join horses_with_keys sire on h.sire_name = sire.horse_name
    left join {{ ref('dim_trainers') }} t on h.current_trainer = t.trainer_name
    left join {{ ref('dim_jockeys') }} j on h.current_jockey = j.jockey_name
    left join {{ ref('dim_owners') }} o on h.current_owner = o.owner_name
),

final as (
    select
        horse_key,
        horse_name,

        -- Pedigree information
        sire_key,
        sire_name,
        dam_key,
        dam_name,

        -- Performance metrics
        current_speed_figure,
        current_power_ranking,

        -- Current connections (names for display)
        current_trainer,
        current_jockey,
        current_owner,

        -- Current connections (foreign keys)
        current_trainer_key,
        current_jockey_key,
        current_owner_key,

        -- Horse attributes
        age,
        sex,

        -- Financial
        career_earnings,

        -- Temporal columns (standardized at end - ALWAYS LAST)
        update_dt,
        last_seen_dt,
        case
            when last_seen_dt >= current_date - interval '90 days' then true
            when last_seen_dt >= current_date - interval '365 days' then true
            else false
        end as is_active,
        current_timestamp as create_dt
    from with_lineage
)

select * from final