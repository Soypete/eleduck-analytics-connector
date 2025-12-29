MODEL (
    name analytics.fact_daily_engagement,
    kind INCREMENTAL_BY_TIME_RANGE (
        time_column metric_date,
        batch_size 30
    ),
    cron '@daily',
    grain (date_key, content_key),
    description 'Daily engagement metrics by content'
);

WITH youtube_metrics AS (
    SELECT
        TO_CHAR(metric_date, 'YYYYMMDD')::INTEGER AS date_key,
        metric_date,
        MD5(COALESCE('youtube', '') || '-' || COALESCE(CAST(video_id AS TEXT), '')) AS content_key,
        'youtube' AS platform,
        views,
        likes,
        comments,
        shares,
        0 AS saves,
        watch_time_seconds,
        avg_view_duration_seconds,
        subscribers_gained AS followers_gained,
        extracted_at
    FROM staging.stg_youtube__video_metrics
    WHERE metric_date BETWEEN @start_date AND @end_date
),

twitter_metrics AS (
    SELECT
        TO_CHAR(created_at::DATE, 'YYYYMMDD')::INTEGER AS date_key,
        created_at::DATE AS metric_date,
        MD5(COALESCE('twitter', '') || '-' || COALESCE(CAST(tweet_id AS TEXT), '')) AS content_key,
        'twitter' AS platform,
        impression_count AS views,
        like_count AS likes,
        reply_count AS comments,
        retweet_count + quote_count AS shares,
        0 AS saves,
        0 AS watch_time_seconds,
        0 AS avg_view_duration_seconds,
        0 AS followers_gained,
        extracted_at
    FROM staging.stg_twitter__tweets
    WHERE created_at::DATE BETWEEN @start_date AND @end_date
),

linkedin_metrics AS (
    SELECT
        TO_CHAR(published_at::DATE, 'YYYYMMDD')::INTEGER AS date_key,
        published_at::DATE AS metric_date,
        MD5(COALESCE('linkedin', '') || '-' || COALESCE(CAST(post_id AS TEXT), '')) AS content_key,
        'linkedin' AS platform,
        impressions AS views,
        likes,
        comments,
        shares,
        0 AS saves,
        0 AS watch_time_seconds,
        0 AS avg_view_duration_seconds,
        0 AS followers_gained,
        extracted_at
    FROM staging.stg_linkedin__posts
    WHERE published_at::DATE BETWEEN @start_date AND @end_date
),

twitch_metrics AS (
    SELECT
        TO_CHAR(started_at::DATE, 'YYYYMMDD')::INTEGER AS date_key,
        started_at::DATE AS metric_date,
        MD5(COALESCE('twitch', '') || '-' || COALESCE(CAST(stream_id AS TEXT), '')) AS content_key,
        'twitch' AS platform,
        viewer_count AS views,
        0 AS likes,
        0 AS comments,
        0 AS shares,
        0 AS saves,
        0 AS watch_time_seconds,
        0 AS avg_view_duration_seconds,
        0 AS followers_gained,
        extracted_at
    FROM staging.stg_twitch__streams
    WHERE started_at::DATE BETWEEN @start_date AND @end_date
),

unioned AS (
    SELECT * FROM youtube_metrics
    UNION ALL
    SELECT * FROM twitter_metrics
    UNION ALL
    SELECT * FROM linkedin_metrics
    UNION ALL
    SELECT * FROM twitch_metrics
),

aggregated AS (
    SELECT
        date_key,
        metric_date,
        content_key,
        MAX(platform) AS platform,
        SUM(views) AS views,
        SUM(likes) AS likes,
        SUM(comments) AS comments,
        SUM(shares) AS shares,
        SUM(saves) AS saves,
        SUM(watch_time_seconds) AS watch_time_seconds,
        AVG(NULLIF(avg_view_duration_seconds, 0)) AS avg_view_duration_seconds,
        SUM(followers_gained) AS followers_gained,
        CURRENT_TIMESTAMP AS sqlmesh_updated_at
    FROM unioned
    GROUP BY 1, 2, 3
)

SELECT * FROM aggregated
