{{
    config(
        materialized='view',
        tags=['spotify', 'staging']
    )
}}

with source as (
    select * from {{ source('raw_spotify', 'spotify_episode_performance') }}
),

renamed as (
    select
        episode_id,
        date::date as metric_date,
        starts,
        streams,
        listeners as unique_listeners,
        avg_listen_seconds,
        -- Calculate completion-related metrics
        case
            when starts > 0 then streams::decimal / starts
            else 0
        end as stream_through_rate,
        -- Metadata for tracking
        current_timestamp as _dbt_loaded_at
    from source
)

select * from renamed
