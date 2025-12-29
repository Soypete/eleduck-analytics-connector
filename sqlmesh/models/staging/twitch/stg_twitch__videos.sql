MODEL (
    name staging.stg_twitch__videos,
    kind VIEW,
    cron '@daily',
    grain video_id,
    description 'Twitch VODs and clips'
);

SELECT
    -- IDs
    id AS video_id,
    stream_id,
    user_id,
    user_login,
    user_name,

    -- Content
    title,
    description,
    type AS video_type,

    -- Duration
    duration AS duration_raw,
    COALESCE(
        EXTRACT(EPOCH FROM duration::INTERVAL)::INT,
        0
    ) AS duration_seconds,

    -- Metrics
    COALESCE(view_count::INT, 0) AS view_count,

    -- Timestamps
    created_at::TIMESTAMP AS created_at,
    published_at::TIMESTAMP AS published_at,

    -- URLs
    url AS video_url,
    thumbnail_url,

    _airbyte_extracted_at AS extracted_at

FROM raw.videos
WHERE id IS NOT NULL
