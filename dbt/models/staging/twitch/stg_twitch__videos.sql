with source as (
    select * from {{ source('twitch', 'videos') }}
),

renamed as (
    select
        -- IDs
        id as video_id,
        stream_id,
        user_id,
        user_login,
        user_name,

        -- Content
        title,
        description,
        type as video_type,
        language,

        -- Duration
        duration as duration_raw,
        -- Parse duration string (e.g., "1h2m3s") to seconds
        coalesce(
            extract(epoch from duration::interval)::int,
            0
        ) as duration_seconds,

        -- Metrics
        coalesce(view_count::int, 0) as view_count,

        -- Timestamps
        created_at::timestamp as created_at,
        published_at::timestamp as published_at,

        -- URLs
        url as video_url,
        thumbnail_url,

        -- Metadata
        _airbyte_extracted_at as extracted_at

    from source
    where id is not null
)

select * from renamed
