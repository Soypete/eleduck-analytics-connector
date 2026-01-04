MODEL (
    name staging.stg_twitch__followers,
    kind VIEW,
    cron '@daily',
    grain follower_id,
    description 'Twitch follower events'
);

SELECT
    -- Follower info
    from_id AS follower_id,
    from_login AS follower_login,
    from_name AS follower_name,

    -- Timestamps
    followed_at::TIMESTAMP AS followed_at,

    _airbyte_extracted_at AS extracted_at

FROM raw.followers
WHERE from_id IS NOT NULL
