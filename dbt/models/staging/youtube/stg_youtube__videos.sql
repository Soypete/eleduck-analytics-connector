with source as (
    select * from {{ source('youtube', 'videos') }}
),

renamed as (
    select
        -- IDs
        id as video_id,

        -- Content
        snippet_title as title,
        snippet_description as description,
        snippet_channel_id as channel_id,
        snippet_channel_title as channel_name,

        -- Categorization
        snippet_category_id as category_id,
        snippet_tags as tags,

        -- Timestamps
        snippet_published_at::timestamp as published_at,

        -- Statistics (at time of sync)
        coalesce(statistics_view_count::bigint, 0) as view_count,
        coalesce(statistics_like_count::bigint, 0) as like_count,
        coalesce(statistics_comment_count::bigint, 0) as comment_count,

        -- Duration
        content_details_duration as duration_iso,

        -- URLs
        'https://youtube.com/watch?v=' || id as video_url,
        snippet_thumbnails_default_url as thumbnail_url,

        -- Metadata
        _airbyte_extracted_at as extracted_at

    from source
    where id is not null
)

select * from renamed
