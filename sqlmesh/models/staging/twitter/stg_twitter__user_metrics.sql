MODEL (
    name staging.stg_twitter__user_metrics,
    kind VIEW,
    cron '@daily',
    grain (user_id, metric_date),
    description 'Twitter user metrics'
);

SELECT
    -- User info
    id AS user_id,
    username,
    name AS display_name,
    description AS bio,

    -- Metrics
    COALESCE(public_metrics_followers_count::INT, 0) AS followers_count,
    COALESCE(public_metrics_following_count::INT, 0) AS following_count,
    COALESCE(public_metrics_tweet_count::INT, 0) AS tweet_count,
    COALESCE(public_metrics_listed_count::INT, 0) AS listed_count,

    -- Verification
    verified::BOOLEAN AS is_verified,

    -- Timestamps
    created_at::TIMESTAMP AS account_created_at,
    _airbyte_extracted_at::DATE AS metric_date,
    _airbyte_extracted_at AS extracted_at

FROM raw.user_metrics
WHERE id IS NOT NULL
