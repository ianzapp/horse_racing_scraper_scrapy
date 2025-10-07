{{
  config(
    materialized='table',
    unique_key='payout_key'
  )
}}

with payout_data as (
    select
        p.*,
        t.track_key,
        -- Create composite race key from track and race details
        {{ dbt_utils.generate_surrogate_key(['t.track_key', 'p.race_date', 'p.race_number']) }} as race_key
    from {{ ref('stg_race_payouts') }} p
    left join {{ ref('dim_tracks') }} t
        on p.track_name = t.track_name
    where p.track_name is not null
        and p.race_date is not null
        and p.race_number is not null
),

final as (
    select
        {{ dbt_utils.generate_surrogate_key(['business_key']) }} as payout_key,
        race_key,
        track_key,

        -- Race identifiers
        track_name,
        race_date,
        race_number,

        -- Win/Place/Show payouts
        win_payout,
        place_payout,
        show_payout,

        -- Exotic bet payouts
        exacta_payout,
        trifecta_payout,
        superfecta_payout,

        -- Winning combinations
        win_horse_name,
        place_horses,
        show_horses,
        exacta_combination,
        trifecta_combination,
        superfecta_combination,

        -- Pool information
        total_pool,
        win_pool,

        -- Metadata
        business_key,
        source_url,
        crawl_run_id,
        created_at

    from payout_data
)

select * from final