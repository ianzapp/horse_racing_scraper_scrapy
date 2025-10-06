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

all_horses as (
    select * from horse_entries
    union all
    select * from horse_results
),

deduplicated_horses as (
    select
        horse_name,
        -- Take the most complete sire information
        coalesce(
            max(case when sire is not null and sire != '' then sire end),
            max(sire)
        ) as sire,
        max(last_seen) as last_seen
    from all_horses
    group by horse_name
),

final as (
    select
        {{ dbt_utils.generate_surrogate_key(['horse_name']) }} as horse_key,
        horse_name,
        sire,
        last_seen,
        current_timestamp as created_at
    from deduplicated_horses
)

select * from final