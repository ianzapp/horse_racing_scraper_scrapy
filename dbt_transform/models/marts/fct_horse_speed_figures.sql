{{
  config(
    materialized='table',
    unique_key='speed_figure_key'
  )
}}

with speed_data as (
    select
        s.*,
        h.horse_key,
        t.track_key,
        tr.trainer_key,
        j.jockey_key,
        -- Create race key if this is related to a specific race
        case
            when s.track_name is not null and s.race_date is not null and s.race_number is not null
            then {{ dbt_utils.generate_surrogate_key(['t.track_key', 's.race_date', 's.race_number']) }}
            else null
        end as race_key
    from {{ ref('stg_hrn_speed_results') }} s
    left join {{ ref('dim_horses') }} h
        on s.horse_name = h.horse_name
    left join {{ ref('dim_tracks') }} t
        on s.track_name = t.track_name
    left join {{ ref('dim_trainers') }} tr
        on s.trainer_name = tr.trainer_name
    left join {{ ref('dim_jockeys') }} j
        on s.jockey_name = j.jockey_name
),

final as (
    select
        {{ dbt_utils.generate_surrogate_key(['business_key']) }} as speed_figure_key,
        horse_key,
        track_key,
        trainer_key,
        jockey_key,
        race_key,

        -- Horse identification
        horse_name,
        sire_name,

        -- Performance metrics
        hrn_speed_figure,
        power_ranking,
        last_race_speed,
        avg_speed_last_3_races,

        -- Race context
        track_name,
        race_date,
        race_number,
        surface_type,
        distance,
        race_class,

        -- Horse details
        horse_age,
        horse_sex,
        career_earnings,
        race_record,
        last_race_date_raw,

        -- Connection information
        trainer_name,
        jockey_name,
        owner_name,

        -- Ranking metrics
        ranking_change,

        -- Metadata
        business_key,
        source_url,
        crawl_run_id,
        created_at

    from speed_data
    where horse_name is not null  -- Only include records with horse data
)

select * from final