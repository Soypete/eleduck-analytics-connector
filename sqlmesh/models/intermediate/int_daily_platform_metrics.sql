MODEL (
    name staging.int_daily_platform_metrics,
    kind VIEW,
    cron '@daily',
    grain (metric_date, platform),
    description 'Daily aggregated metrics by platform'
);

WITH youtube_daily AS (
    SELECT
        metric_date,
        'youtube' AS platform,
        SUM(views) AS total_views,
        SUM(likes + comments + shares) AS total_engagement,
        COUNT(DISTINCT video_id) AS content_count
    FROM staging.stg_youtube__video_metrics
    GROUP BY 1, 2
),

twitter_daily AS (
    SELECT
        created_at::DATE AS metric_date,
        'twitter' AS platform,
        SUM(impression_count) AS total_views,
        SUM(like_count + reply_count + retweet_count + quote_count) AS total_engagement,
        COUNT(DISTINCT tweet_id) AS content_count
    FROM staging.stg_twitter__tweets
    GROUP BY 1, 2
),

linkedin_daily AS (
    SELECT
        published_at::DATE AS metric_date,
        'linkedin' AS platform,
        SUM(impressions) AS total_views,
        SUM(likes + comments + shares) AS total_engagement,
        COUNT(DISTINCT post_id) AS content_count
    FROM staging.stg_linkedin__posts
    GROUP BY 1, 2
),

twitch_daily AS (
    SELECT
        started_at::DATE AS metric_date,
        'twitch' AS platform,
        SUM(viewer_count) AS total_views,
        0 AS total_engagement,
        COUNT(DISTINCT stream_id) AS content_count
    FROM staging.stg_twitch__streams
    GROUP BY 1, 2
),

unioned AS (
    SELECT * FROM youtube_daily
    UNION ALL
    SELECT * FROM twitter_daily
    UNION ALL
    SELECT * FROM linkedin_daily
    UNION ALL
    SELECT * FROM twitch_daily
)

SELECT
    metric_date,
    platform,
    total_views,
    total_engagement,
    content_count,
    CASE
        WHEN total_views = 0 OR total_views IS NULL THEN 0
        ELSE total_engagement::DECIMAL / total_views::DECIMAL * 100
    END AS avg_engagement_rate
FROM unioned
WHERE metric_date IS NOT NULL
