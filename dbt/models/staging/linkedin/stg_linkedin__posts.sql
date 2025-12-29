with source as (
    select * from {{ source('linkedin', 'posts') }}
),

renamed as (
    select
        -- IDs
        id as post_id,
        author as author_urn,

        -- Content
        commentary as description,
        article_title as title,
        content_type,

        -- Visibility
        visibility,

        -- Timestamps
        created_at::timestamp as published_at,

        -- Engagement metrics
        coalesce(total_share_statistics_like_count::int, 0) as like_count,
        coalesce(total_share_statistics_comment_count::int, 0) as comment_count,
        coalesce(total_share_statistics_share_count::int, 0) as share_count,
        coalesce(total_share_statistics_click_count::int, 0) as click_count,
        coalesce(total_share_statistics_impression_count::int, 0) as impression_count,
        coalesce(total_share_statistics_engagement::decimal, 0) as engagement_rate,

        -- URLs
        permalink_suffix as post_url,

        -- Metadata
        _airbyte_extracted_at as extracted_at

    from source
    where id is not null
)

select * from renamed
