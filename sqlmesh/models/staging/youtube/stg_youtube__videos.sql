MODEL (
    name staging.stg_youtube__videos,
    kind VIEW,
    cron '@daily',
    grain video_id,
    description 'Staged YouTube videos with cleaned and renamed columns'
);

SELECT
    -- IDs
    id AS video_id,

    -- Content
    snippet_title AS title,
    snippet_description AS description,
    snippet_channel_id AS channel_id,
    snippet_channel_title AS channel_name,

    -- Categorization
    snippet_category_id AS category_id,
    snippet_tags AS tags,

    -- Timestamps
    snippet_published_at::TIMESTAMP AS published_at,

    -- Statistics (at time of sync)
    COALESCE(statistics_view_count::BIGINT, 0) AS view_count,
    COALESCE(statistics_like_count::BIGINT, 0) AS like_count,
    COALESCE(statistics_comment_count::BIGINT, 0) AS comment_count,

    -- Duration
    content_details_duration AS duration_iso,

    -- URLs
    'https://youtube.com/watch?v=' || id AS video_url,
    snippet_thumbnails_default_url AS thumbnail_url,

    -- Metadata
    _airbyte_extracted_at AS extracted_at

FROM raw.videos
WHERE id IS NOT NULL
