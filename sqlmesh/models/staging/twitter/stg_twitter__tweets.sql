MODEL (
    name staging.stg_twitter__tweets,
    kind VIEW,
    cron '@daily',
    grain tweet_id,
    description 'Twitter tweet records'
);

SELECT
    -- IDs
    id AS tweet_id,
    author_id,
    conversation_id,
    in_reply_to_user_id,

    -- Content
    text,

    -- Engagement metrics
    COALESCE(public_metrics_retweet_count::INT, 0) AS retweet_count,
    COALESCE(public_metrics_reply_count::INT, 0) AS reply_count,
    COALESCE(public_metrics_like_count::INT, 0) AS like_count,
    COALESCE(public_metrics_quote_count::INT, 0) AS quote_count,
    COALESCE(public_metrics_impression_count::INT, 0) AS impression_count,

    -- Timestamps
    created_at::TIMESTAMP AS created_at,

    -- URLs
    'https://twitter.com/i/web/status/' || id AS tweet_url,

    _airbyte_extracted_at AS extracted_at

FROM raw.tweets
WHERE id IS NOT NULL
