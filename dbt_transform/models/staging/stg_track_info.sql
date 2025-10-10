{{
  config(
    materialized='incremental',
    unique_key='id',
    on_schema_change='fail'
  )
}}

with source_data as (
    select
        id,
        spider_name,
        raw_data,
        source_url,
        data_hash,
        created_at as scraped_dt
    from {{ source('public', 'raw_scraped_data') }}
    where item_type = 'track_info'

    {% if is_incremental() %}
        and created_at > (select max(scraped_dt) from {{ this }})
    {% endif %}
),

parsed_data as (
    select
        id,
        spider_name,

        -- Extract and clean track information
        trim(raw_data->>'track_name') as track_name,
        trim(raw_data->>'track_abbreviation') as track_abbreviation,
        trim(raw_data->>'track_description') as track_description,
        raw_data->>'track_website' as track_website,

        -- Enhanced location parsing with international support
        -- Extract country (defaults to USA)
        case
            when lower(raw_data->>'track_location') like '%australia%' then 'Australia'
            when lower(raw_data->>'track_location') like '%hong kong%' then 'Hong Kong'
            when lower(raw_data->>'track_location') like '%canada%' then 'Canada'
            when lower(raw_data->>'track_location') like '%puerto rico%' then 'Puerto Rico'
            when lower(raw_data->>'track_location') like '%united kingdom%' or lower(raw_data->>'track_location') like '%england%' or lower(raw_data->>'track_location') like '%uk%' then 'United Kingdom'
            when lower(raw_data->>'track_location') like '%ireland%' then 'Ireland'
            when lower(raw_data->>'track_location') like '%france%' then 'France'
            when lower(raw_data->>'track_location') like '%japan%' then 'Japan'
            when lower(raw_data->>'track_location') like '%dubai%' or lower(raw_data->>'track_location') like '%uae%' then 'United Arab Emirates'
            else 'USA'
        end as track_country,

        -- Extract state/province with normalization to codes
        case
            -- International locations - extract state/province
            when lower(raw_data->>'track_location') like '%queensland, australia%' then 'QLD'
            when lower(raw_data->>'track_location') like '%new south wales, australia%' then 'NSW'
            when lower(raw_data->>'track_location') like '%victoria, australia%' then 'VIC'
            when lower(raw_data->>'track_location') like '%western australia%' then 'WA'
            when lower(raw_data->>'track_location') like '%south australia%' then 'SA'
            when lower(raw_data->>'track_location') like '%tasmania, australia%' then 'TAS'
            when lower(raw_data->>'track_location') like '%northern territory, australia%' then 'NT'
            when lower(raw_data->>'track_location') like '%hong kong%' then null -- Hong Kong doesn't use state codes
            when lower(raw_data->>'track_location') like '%puerto rico%' then 'PR'

            -- Canadian provinces
            when lower(raw_data->>'track_location') like '%ontario, canada%' then 'ON'
            when lower(raw_data->>'track_location') like '%quebec, canada%' then 'QC'
            when lower(raw_data->>'track_location') like '%british columbia, canada%' then 'BC'
            when lower(raw_data->>'track_location') like '%alberta, canada%' then 'AB'
            when lower(raw_data->>'track_location') like '%manitoba, canada%' then 'MB'
            when lower(raw_data->>'track_location') like '%saskatchewan, canada%' then 'SK'
            when lower(raw_data->>'track_location') like '%nova scotia, canada%' then 'NS'
            when lower(raw_data->>'track_location') like '%new brunswick, canada%' then 'NB'
            when lower(raw_data->>'track_location') like '%newfoundland, canada%' then 'NL'
            when lower(raw_data->>'track_location') like '%prince edward island, canada%' then 'PE'
            when lower(raw_data->>'track_location') like '%yukon, canada%' then 'YT'
            when lower(raw_data->>'track_location') like '%northwest territories, canada%' then 'NT'
            when lower(raw_data->>'track_location') like '%nunavut, canada%' then 'NU'
            -- Handle simple ', Canada' format
            when lower(raw_data->>'track_location') like '%, canada' and not lower(raw_data->>'track_location') like '%,%,%' then null

            -- US state code extraction (existing 2-letter codes)
            when raw_data->>'track_location' ~ ', [A-Z]{2}$' then
                trim(split_part(raw_data->>'track_location', ',', -1))

            -- US full state name to code conversion
            when lower(raw_data->>'track_location') like '%alabama%' then 'AL'
            when lower(raw_data->>'track_location') like '%alaska%' then 'AK'
            when lower(raw_data->>'track_location') like '%arizona%' then 'AZ'
            when lower(raw_data->>'track_location') like '%arkansas%' then 'AR'
            when lower(raw_data->>'track_location') like '%california%' then 'CA'
            when lower(raw_data->>'track_location') like '%colorado%' then 'CO'
            when lower(raw_data->>'track_location') like '%connecticut%' then 'CT'
            when lower(raw_data->>'track_location') like '%delaware%' then 'DE'
            when lower(raw_data->>'track_location') like '%florida%' then 'FL'
            when lower(raw_data->>'track_location') like '%georgia%' then 'GA'
            when lower(raw_data->>'track_location') like '%hawaii%' then 'HI'
            when lower(raw_data->>'track_location') like '%idaho%' then 'ID'
            when lower(raw_data->>'track_location') like '%illinois%' then 'IL'
            when lower(raw_data->>'track_location') like '%indiana%' then 'IN'
            when lower(raw_data->>'track_location') like '%iowa%' then 'IA'
            when lower(raw_data->>'track_location') like '%kansas%' then 'KS'
            when lower(raw_data->>'track_location') like '%kentucky%' then 'KY'
            when lower(raw_data->>'track_location') like '%louisiana%' then 'LA'
            when lower(raw_data->>'track_location') like '%maine%' then 'ME'
            when lower(raw_data->>'track_location') like '%maryland%' then 'MD'
            when lower(raw_data->>'track_location') like '%massachusetts%' then 'MA'
            when lower(raw_data->>'track_location') like '%michigan%' then 'MI'
            when lower(raw_data->>'track_location') like '%minnesota%' then 'MN'
            when lower(raw_data->>'track_location') like '%mississippi%' then 'MS'
            when lower(raw_data->>'track_location') like '%missouri%' then 'MO'
            when lower(raw_data->>'track_location') like '%montana%' then 'MT'
            when lower(raw_data->>'track_location') like '%nebraska%' then 'NE'
            when lower(raw_data->>'track_location') like '%nevada%' then 'NV'
            when lower(raw_data->>'track_location') like '%new hampshire%' then 'NH'
            when lower(raw_data->>'track_location') like '%new jersey%' then 'NJ'
            when lower(raw_data->>'track_location') like '%new mexico%' then 'NM'
            when lower(raw_data->>'track_location') like '%new york%' then 'NY'
            when lower(raw_data->>'track_location') like '%north carolina%' then 'NC'
            when lower(raw_data->>'track_location') like '%north dakota%' then 'ND'
            when lower(raw_data->>'track_location') like '%ohio%' then 'OH'
            when lower(raw_data->>'track_location') like '%oklahoma%' then 'OK'
            when lower(raw_data->>'track_location') like '%oregon%' then 'OR'
            when lower(raw_data->>'track_location') like '%pennsylvania%' then 'PA'
            when lower(raw_data->>'track_location') like '%rhode island%' then 'RI'
            when lower(raw_data->>'track_location') like '%south carolina%' then 'SC'
            when lower(raw_data->>'track_location') like '%south dakota%' then 'SD'
            when lower(raw_data->>'track_location') like '%tennessee%' then 'TN'
            when lower(raw_data->>'track_location') like '%texas%' then 'TX'
            when lower(raw_data->>'track_location') like '%utah%' then 'UT'
            when lower(raw_data->>'track_location') like '%vermont%' then 'VT'
            when lower(raw_data->>'track_location') like '%virginia%' then 'VA'
            when lower(raw_data->>'track_location') like '%washington%' then 'WA'
            when lower(raw_data->>'track_location') like '%west virginia%' then 'WV'
            when lower(raw_data->>'track_location') like '%wisconsin%' then 'WI'
            when lower(raw_data->>'track_location') like '%wyoming%' then 'WY'
            else null
        end as track_state,

        -- Extract city with enhanced international parsing
        case
            -- International city extraction
            when lower(raw_data->>'track_location') like '%queensland, australia%' then
                trim(regexp_replace(raw_data->>'track_location', ', Queensland, Australia', '', 'i'))
            when lower(raw_data->>'track_location') like '%new south wales, australia%' then
                trim(regexp_replace(raw_data->>'track_location', ', New South Wales, Australia', '', 'i'))
            when lower(raw_data->>'track_location') like '%victoria, australia%' then
                trim(regexp_replace(raw_data->>'track_location', ', Victoria, Australia', '', 'i'))
            when lower(raw_data->>'track_location') like '%western australia%' then
                trim(regexp_replace(raw_data->>'track_location', ', Western Australia', '', 'i'))
            when lower(raw_data->>'track_location') like '%south australia%' then
                trim(regexp_replace(raw_data->>'track_location', ', South Australia', '', 'i'))
            when lower(raw_data->>'track_location') like '%tasmania, australia%' then
                trim(regexp_replace(raw_data->>'track_location', ', Tasmania, Australia', '', 'i'))
            when lower(raw_data->>'track_location') like '%northern territory, australia%' then
                trim(regexp_replace(raw_data->>'track_location', ', Northern Territory, Australia', '', 'i'))
            when lower(raw_data->>'track_location') like '%hong kong%' then
                trim(regexp_replace(raw_data->>'track_location', ', Hong Kong', '', 'i'))
            when lower(raw_data->>'track_location') like '%puerto rico%' then
                trim(regexp_replace(raw_data->>'track_location', ', Puerto Rico', '', 'i'))

            -- Canadian city extraction
            when lower(raw_data->>'track_location') like '%ontario, canada%' then
                trim(regexp_replace(raw_data->>'track_location', ', Ontario, Canada', '', 'i'))
            when lower(raw_data->>'track_location') like '%quebec, canada%' then
                trim(regexp_replace(raw_data->>'track_location', ', Quebec, Canada', '', 'i'))
            when lower(raw_data->>'track_location') like '%british columbia, canada%' then
                trim(regexp_replace(raw_data->>'track_location', ', British Columbia, Canada', '', 'i'))
            when lower(raw_data->>'track_location') like '%alberta, canada%' then
                trim(regexp_replace(raw_data->>'track_location', ', Alberta, Canada', '', 'i'))
            when lower(raw_data->>'track_location') like '%manitoba, canada%' then
                trim(regexp_replace(raw_data->>'track_location', ', Manitoba, Canada', '', 'i'))
            when lower(raw_data->>'track_location') like '%saskatchewan, canada%' then
                trim(regexp_replace(raw_data->>'track_location', ', Saskatchewan, Canada', '', 'i'))
            when lower(raw_data->>'track_location') like '%nova scotia, canada%' then
                trim(regexp_replace(raw_data->>'track_location', ', Nova Scotia, Canada', '', 'i'))
            when lower(raw_data->>'track_location') like '%new brunswick, canada%' then
                trim(regexp_replace(raw_data->>'track_location', ', New Brunswick, Canada', '', 'i'))
            when lower(raw_data->>'track_location') like '%newfoundland, canada%' then
                trim(regexp_replace(raw_data->>'track_location', ', Newfoundland, Canada', '', 'i'))
            when lower(raw_data->>'track_location') like '%prince edward island, canada%' then
                trim(regexp_replace(raw_data->>'track_location', ', Prince Edward Island, Canada', '', 'i'))
            when lower(raw_data->>'track_location') like '%yukon, canada%' then
                trim(regexp_replace(raw_data->>'track_location', ', Yukon, Canada', '', 'i'))
            when lower(raw_data->>'track_location') like '%northwest territories, canada%' then
                trim(regexp_replace(raw_data->>'track_location', ', Northwest Territories, Canada', '', 'i'))
            when lower(raw_data->>'track_location') like '%nunavut, canada%' then
                trim(regexp_replace(raw_data->>'track_location', ', Nunavut, Canada', '', 'i'))
            -- Handle simple ', Canada' format (city, country)
            when lower(raw_data->>'track_location') like '%, canada' and not lower(raw_data->>'track_location') like '%,%,%' then
                trim(regexp_replace(raw_data->>'track_location', ', Canada', '', 'i'))

            -- US city extraction for existing 2-letter state codes
            when raw_data->>'track_location' ~ ', [A-Z]{2}$' then
                trim(regexp_replace(raw_data->>'track_location', ', [A-Z]{2}$', ''))

            -- US city extraction for full state names (remove county references)
            when lower(raw_data->>'track_location') like '%county,%' then
                trim(split_part(raw_data->>'track_location', ',', 1))
            else trim(raw_data->>'track_location')
        end as track_city,

        -- Metadata (at end)
        source_url,
        data_hash,
        scraped_dt

    from source_data
),

cleaned_data as (
    select
        -- Business attributes
        id,
        spider_name,
        track_name,
        track_abbreviation,
        track_description,
        track_website,
        track_country,
        track_state,
        track_city,

        -- Data quality flags
        case when track_name is null or track_name = '' then true else false end as missing_track_name,

        -- Metadata (at end)
        source_url,
        data_hash,
        scraped_dt

    from parsed_data
)

select * from cleaned_data
where not missing_track_name