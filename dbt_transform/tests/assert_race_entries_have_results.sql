-- Test that races with entries should have some results
-- (Not all races will have results immediately, but most should)

with entries_by_race as (
    select
        race_key,
        count(*) as entry_count
    from {{ ref('fct_race_entries') }}
    group by race_key
),

results_by_race as (
    select
        race_key,
        count(*) as result_count
    from {{ ref('fct_race_results') }}
    group by race_key
),

missing_results as (
    select
        e.race_key,
        e.entry_count,
        coalesce(r.result_count, 0) as result_count
    from entries_by_race e
    left join results_by_race r on e.race_key = r.race_key
    where coalesce(r.result_count, 0) = 0
        and e.entry_count > 0
        -- Only check races from more than 1 day ago
        and exists (
            select 1
            from {{ ref('fct_races') }} fr
            where fr.race_key = e.race_key
                and fr.race_date < current_date - interval '1 day'
        )
)

select * from missing_results