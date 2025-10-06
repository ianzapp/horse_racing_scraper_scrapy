{{
  config(
    materialized='table',
    unique_key='trainer_key'
  )
}}

with trainer_data as (
    select
        trainer,
        max(created_at) as last_seen,
        count(*) as total_entries
    from {{ ref('stg_race_entries') }}
    where trainer is not null and trainer != ''
    group by trainer
),

final as (
    select
        {{ dbt_utils.generate_surrogate_key(['trainer']) }} as trainer_key,
        trainer as trainer_name,
        last_seen,
        total_entries,
        current_timestamp as created_at
    from trainer_data
)

select * from final