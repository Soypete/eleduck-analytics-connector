MODEL (
    name staging.stg_twitch__streams,
    kind VIEW,
    cron '@daily',
    grain stream_id,
    description 'Twitch stream records'
);

SELECT
    -- IDs
    id AS stream_id,
    user_id,
    user_login,
    user_name,

    -- Game/Category
    game_id,
    game_name,

    -- Content
    title,
    type AS stream_type,

    -- Metrics
    COALESCE(viewer_count::INT, 0) AS viewer_count,

    -- Timestamps
    started_at::TIMESTAMP AS started_at,

    -- Metadata
    language,
    is_mature::BOOLEAN AS is_mature,

    -- URLs
    'https://twitch.tv/' || user_login AS stream_url,
    thumbnail_url,

    _airbyte_extracted_at AS extracted_at

FROM raw.streams
WHERE id IS NOT NULL
