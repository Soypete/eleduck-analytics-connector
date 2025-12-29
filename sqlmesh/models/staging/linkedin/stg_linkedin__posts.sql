MODEL (
    name staging.stg_linkedin__posts,
    kind VIEW,
    cron '@daily',
    grain post_id,
    description 'LinkedIn post records'
);

SELECT
    -- IDs
    id AS post_id,
    author AS author_id,

    -- Content
    COALESCE(specific_content_share_commentary_text, commentary) AS title,
    text AS description,
    content_landing_page_content_type AS content_type,

    -- Timestamps
    created_time::TIMESTAMP AS published_at,

    -- Engagement metrics
    COALESCE(total_share_statistics_impression_count::INT, 0) AS impressions,
    COALESCE(total_share_statistics_click_count::INT, 0) AS clicks,
    COALESCE(total_share_statistics_like_count::INT, 0) AS likes,
    COALESCE(total_share_statistics_comment_count::INT, 0) AS comments,
    COALESCE(total_share_statistics_share_count::INT, 0) AS shares,

    -- Calculated engagement rate
    CASE
        WHEN COALESCE(total_share_statistics_impression_count::INT, 1) = 0 THEN 0
        ELSE (
            COALESCE(total_share_statistics_like_count::INT, 0) +
            COALESCE(total_share_statistics_comment_count::INT, 0) +
            COALESCE(total_share_statistics_share_count::INT, 0)
        )::DECIMAL / COALESCE(total_share_statistics_impression_count::INT, 1)::DECIMAL * 100
    END AS engagement_rate,

    -- URLs
    'https://linkedin.com/feed/update/' || id AS post_url,

    _airbyte_extracted_at AS extracted_at

FROM raw.posts
WHERE id IS NOT NULL
