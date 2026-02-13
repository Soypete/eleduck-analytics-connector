MODEL (
    name analytics.fact_content_performance,
    kind FULL,
    cron '@daily',
    grain content_key,
    description 'Content performance summary metrics'
);

WITH daily_engagement AS (
    SELECT * FROM analytics.fact_daily_engagement
),

content_dim AS (
    SELECT * FROM analytics.dim_content
),

aggregated AS (
    SELECT
        e.content_key,
        SUM(e.views) AS total_views,
        SUM(e.likes) AS total_likes,
        SUM(e.comments) AS total_comments,
        SUM(e.shares) AS total_shares,
        SUM(e.watch_time_seconds) AS total_watch_time_seconds,
        MIN(d.full_date) AS first_metric_date,
        MAX(d.full_date) AS last_metric_date,
        COUNT(DISTINCT e.date_key) AS days_with_metrics
    FROM daily_engagement e
    JOIN analytics.dim_date d ON e.date_key = d.date_key
    GROUP BY 1
)

SELECT
    a.content_key,
    c.platform_key,
    a.total_views,
    a.total_likes,
    a.total_comments,
    a.total_shares,
    a.total_watch_time_seconds,
    a.first_metric_date,
    a.last_metric_date,
    a.days_with_metrics,
    CASE
        WHEN a.days_with_metrics = 0 THEN 0
        ELSE a.total_views::DECIMAL / a.days_with_metrics::DECIMAL
    END AS avg_daily_views,
    CURRENT_TIMESTAMP AS sqlmesh_updated_at
FROM aggregated a
LEFT JOIN content_dim c ON a.content_key = c.content_key
