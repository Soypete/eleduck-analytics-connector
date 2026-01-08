{{
    config(
        materialized='view',
        tags=['youtube', 'staging']
    )
}}

with source as (
    select * from {{ source('raw_youtube', 'youtube_videos') }}
),

renamed as (
    select
        id as video_id,
        snippet->>'title' as title,
        (snippet->>'publishedAt')::date as published_date,
        snippet->>'description' as description,
        snippet->>'channelId' as channel_id,
        snippet->>'channelTitle' as channel_title,
        -- Parse ISO 8601 duration to seconds (PT#H#M#S format)
        {{ parse_youtube_duration("content_details->>'duration'") }} as duration_seconds,
        content_details->>'definition' as video_definition,
        -- Metadata for tracking
        current_timestamp as _dbt_loaded_at
    from source
)

select * from renamed
