{{
    config(
        materialized='view',
        tags=['spotify', 'staging']
    )
}}

with source as (
    select * from {{ source('raw_spotify', 'spotify_show_stats') }}
),

renamed as (
    select
        date::date as stats_date,
        total_streams,
        followers,
        total_listeners,
        -- Metadata for tracking
        current_timestamp as _dbt_loaded_at
    from source
)

select * from renamed
