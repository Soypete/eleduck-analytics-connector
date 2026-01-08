{{
    config(
        materialized='view',
        tags=['youtube', 'staging']
    )
}}

with source as (
    select * from {{ source('raw_youtube', 'youtube_daily_stats') }}
),

renamed as (
    select
        video_id,
        date::date as metric_date,
        views,
        watch_time_minutes,
        average_view_duration as avg_view_seconds,
        likes,
        comments,
        -- Calculated metrics
        case
            when views > 0 then watch_time_minutes::decimal / views
            else 0
        end as minutes_per_view,
        -- Metadata for tracking
        current_timestamp as _dbt_loaded_at
    from source
)

select * from renamed
