MODEL (
    name staging.stg_linkedin__page_stats,
    kind VIEW,
    cron '@daily',
    grain (page_id, metric_date),
    description 'LinkedIn page statistics'
);

SELECT
    -- Page info
    organization AS page_id,
    organization_name AS page_name,

    -- Metrics
    COALESCE(follower_count::INT, 0) AS follower_count,
    COALESCE(page_statistics_views_all_page_views::INT, 0) AS page_views,
    COALESCE(page_statistics_views_unique_visitors::INT, 0) AS unique_visitors,

    -- Timestamps
    time_range_start::DATE AS metric_date,
    _airbyte_extracted_at AS extracted_at

FROM raw.page_stats
WHERE organization IS NOT NULL
