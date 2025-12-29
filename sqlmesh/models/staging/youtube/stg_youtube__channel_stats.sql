MODEL (
    name staging.stg_youtube__channel_stats,
    kind VIEW,
    cron '@daily',
    grain (channel_id, metric_date),
    description 'YouTube channel statistics'
);

SELECT
    -- IDs
    id AS channel_id,

    -- Channel info
    snippet_title AS channel_name,
    snippet_description AS description,
    snippet_custom_url AS custom_url,
    snippet_country AS country,

    -- Statistics
    COALESCE(statistics_subscriber_count::BIGINT, 0) AS subscriber_count,
    COALESCE(statistics_video_count::BIGINT, 0) AS video_count,
    COALESCE(statistics_view_count::BIGINT, 0) AS view_count,

    -- Hidden subscriber count flag
    COALESCE(statistics_hidden_subscriber_count::BOOLEAN, FALSE) AS is_subscriber_count_hidden,

    -- Timestamps
    snippet_published_at::TIMESTAMP AS channel_created_at,
    _airbyte_extracted_at::DATE AS metric_date,
    _airbyte_extracted_at AS extracted_at

FROM raw.channel_stats
WHERE id IS NOT NULL
