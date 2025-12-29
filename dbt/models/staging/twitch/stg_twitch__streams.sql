with source as (
    select * from {{ source('twitch', 'streams') }}
),

renamed as (
    select
        -- IDs
        id as stream_id,
        user_id,
        user_login,
        user_name,

        -- Game/Category
        game_id,
        game_name,

        -- Content
        title,
        type as stream_type,
        language,

        -- Metrics
        coalesce(viewer_count::int, 0) as viewer_count,

        -- Timestamps
        started_at::timestamp as started_at,
        ended_at::timestamp as ended_at,

        -- URLs
        thumbnail_url,
        'https://twitch.tv/' || user_login as stream_url,

        -- Tags
        tags,

        -- Metadata
        _airbyte_extracted_at as extracted_at

    from source
    where id is not null
)

select * from renamed
