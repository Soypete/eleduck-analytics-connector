with source as (
    select * from {{ source('youtube', 'channel_stats') }}
),

renamed as (
    select
        -- IDs
        id as channel_id,

        -- Content
        snippet_title as channel_title,
        snippet_description as description,
        snippet_custom_url as custom_url,
        snippet_country as country,

        -- Statistics
        coalesce(statistics_subscriber_count::bigint, 0) as subscriber_count,
        coalesce(statistics_video_count::bigint, 0) as video_count,
        coalesce(statistics_view_count::bigint, 0) as view_count,

        -- Timestamps
        snippet_published_at::timestamp as created_at,
        date::date as metric_date,

        -- Branding
        branding_settings_image_banner_external_url as banner_url,

        -- Metadata
        _airbyte_extracted_at as extracted_at

    from source
    where id is not null
)

select * from renamed
