{{
  config(
    materialized='table',
    unique_key='result_key'
  )
}}

with race_results as (
    select * from {{ ref('stg_race_results') }}
),

races as (
    select * from {{ ref('fct_races') }}
),

horses as (
    select * from {{ ref('dim_horses') }}
),

result_details as (
    select
        rr.*,
        r.race_key,
        h.horse_key
    from race_results rr
    left join races r on rr.track_name = r.track_name
        and rr.race_date = r.race_date
        and rr.race_number = r.race_number
    left join horses h on rr.horse_name = h.horse_name
),

final as (
    select
        {{ dbt_utils.generate_surrogate_key(['track_name', 'race_date', 'race_number', 'horse_name']) }} as result_key,
        race_key,
        horse_key,
        track_name,
        race_date,
        race_number,
        horse_name,
        finish_position,
        is_winner,
        in_money,
        win_payout,
        place_payout,
        show_payout,
        source_url,
        created_at as scraped_at
    from result_details
)

select * from final