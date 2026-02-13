MODEL (
    name staging.stg_youtube__video_metrics,
    kind VIEW,
    cron '@daily',
    grain (video_id, metric_date),
    description 'Daily video performance metrics'
);

SELECT
    video_id,
    date::DATE AS metric_date,

    -- Views
    COALESCE(views::BIGINT, 0) AS views,
    COALESCE(estimated_minutes_watched::BIGINT, 0) * 60 AS watch_time_seconds,

    -- Engagement
    COALESCE(likes::BIGINT, 0) AS likes,
    COALESCE(comments::BIGINT, 0) AS comments,
    COALESCE(shares::BIGINT, 0) AS shares,
    COALESCE(dislikes::BIGINT, 0) AS dislikes,

    -- Calculated
    CASE
        WHEN COALESCE(views::BIGINT, 0) = 0 OR views IS NULL THEN 0
        ELSE (COALESCE(estimated_minutes_watched::BIGINT, 0) * 60)::DECIMAL / views::DECIMAL
    END AS avg_view_duration_seconds,

    -- Subscribers
    COALESCE(subscribers_gained::INT, 0) AS subscribers_gained,
    COALESCE(subscribers_lost::INT, 0) AS subscribers_lost,

    _airbyte_extracted_at AS extracted_at

FROM raw.video_metrics
WHERE video_id IS NOT NULL AND date IS NOT NULL
