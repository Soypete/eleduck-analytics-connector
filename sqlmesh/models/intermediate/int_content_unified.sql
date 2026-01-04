MODEL (
    name staging.int_content_unified,
    kind VIEW,
    cron '@daily',
    grain content_key,
    description 'Unified content across all platforms (YouTube, Twitch, Twitter, LinkedIn)'
);

WITH youtube_content AS (
    SELECT
        'youtube' AS platform,
        video_id AS native_id,
        'video' AS content_type,
        title,
        description,
        video_url AS url,
        thumbnail_url,
        published_at,
        extracted_at
    FROM staging.stg_youtube__videos
),

twitch_content AS (
    SELECT
        'twitch' AS platform,
        stream_id AS native_id,
        'stream' AS content_type,
        title,
        NULL AS description,
        stream_url AS url,
        thumbnail_url,
        started_at AS published_at,
        extracted_at
    FROM staging.stg_twitch__streams
),

twitter_content AS (
    SELECT
        'twitter' AS platform,
        tweet_id AS native_id,
        'tweet' AS content_type,
        text AS title,
        NULL AS description,
        tweet_url AS url,
        NULL AS thumbnail_url,
        created_at AS published_at,
        extracted_at
    FROM staging.stg_twitter__tweets
),

linkedin_content AS (
    SELECT
        'linkedin' AS platform,
        post_id AS native_id,
        'post' AS content_type,
        title,
        description,
        post_url AS url,
        NULL AS thumbnail_url,
        published_at,
        extracted_at
    FROM staging.stg_linkedin__posts
),

unioned AS (
    SELECT * FROM youtube_content
    UNION ALL
    SELECT * FROM twitch_content
    UNION ALL
    SELECT * FROM twitter_content
    UNION ALL
    SELECT * FROM linkedin_content
)

SELECT
    MD5(COALESCE(CAST(platform AS TEXT), '') || '-' || COALESCE(CAST(native_id AS TEXT), '')) AS content_key,
    platform,
    native_id,
    content_type,
    title,
    description,
    url,
    thumbnail_url,
    published_at,
    extracted_at
FROM unioned
