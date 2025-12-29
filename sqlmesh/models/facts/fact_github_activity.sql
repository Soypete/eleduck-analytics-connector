MODEL (
    name analytics.fact_github_activity,
    kind INCREMENTAL_BY_TIME_RANGE (
        time_column activity_date,
        batch_size 30
    ),
    cron '@daily',
    grain (date_key, repo_key),
    description 'Daily GitHub activity by repository'
);

WITH commits AS (
    SELECT
        TO_CHAR(committed_at::DATE, 'YYYYMMDD')::INTEGER AS date_key,
        committed_at::DATE AS activity_date,
        repo_full_name,
        COUNT(*) AS commits,
        SUM(lines_added) AS lines_added,
        SUM(lines_deleted) AS lines_deleted,
        COUNT(DISTINCT author_email) AS unique_contributors
    FROM staging.stg_github__commits
    WHERE committed_at::DATE BETWEEN @start_date AND @end_date
    GROUP BY 1, 2, 3
),

prs AS (
    SELECT
        TO_CHAR(created_at::DATE, 'YYYYMMDD')::INTEGER AS date_key,
        created_at::DATE AS activity_date,
        repo_full_name,
        COUNT(*) AS prs_opened,
        COUNT(CASE WHEN merged_at IS NOT NULL THEN 1 END) AS prs_merged,
        COUNT(CASE WHEN closed_at IS NOT NULL AND merged_at IS NULL THEN 1 END) AS prs_closed
    FROM staging.stg_github__pull_requests
    WHERE created_at::DATE BETWEEN @start_date AND @end_date
    GROUP BY 1, 2, 3
),

issues AS (
    SELECT
        TO_CHAR(created_at::DATE, 'YYYYMMDD')::INTEGER AS date_key,
        created_at::DATE AS activity_date,
        repo_full_name,
        COUNT(*) AS issues_opened,
        COUNT(CASE WHEN closed_at IS NOT NULL THEN 1 END) AS issues_closed
    FROM staging.stg_github__issues
    WHERE created_at::DATE BETWEEN @start_date AND @end_date
    GROUP BY 1, 2, 3
),

repos AS (
    SELECT
        repo_key,
        repo_full_name
    FROM analytics.dim_repository
),

combined AS (
    SELECT
        COALESCE(c.date_key, p.date_key, i.date_key) AS date_key,
        COALESCE(c.activity_date, p.activity_date, i.activity_date) AS activity_date,
        COALESCE(c.repo_full_name, p.repo_full_name, i.repo_full_name) AS repo_full_name,
        COALESCE(c.commits, 0) AS commits,
        COALESCE(c.lines_added, 0) AS lines_added,
        COALESCE(c.lines_deleted, 0) AS lines_deleted,
        COALESCE(c.unique_contributors, 0) AS unique_contributors,
        COALESCE(p.prs_opened, 0) AS prs_opened,
        COALESCE(p.prs_merged, 0) AS prs_merged,
        COALESCE(p.prs_closed, 0) AS prs_closed,
        COALESCE(i.issues_opened, 0) AS issues_opened,
        COALESCE(i.issues_closed, 0) AS issues_closed
    FROM commits c
    FULL OUTER JOIN prs p ON c.date_key = p.date_key AND c.repo_full_name = p.repo_full_name
    FULL OUTER JOIN issues i ON COALESCE(c.date_key, p.date_key) = i.date_key
        AND COALESCE(c.repo_full_name, p.repo_full_name) = i.repo_full_name
)

SELECT
    c.date_key,
    c.activity_date,
    r.repo_key,
    c.commits,
    c.lines_added,
    c.lines_deleted,
    c.unique_contributors,
    c.prs_opened,
    c.prs_merged,
    c.prs_closed,
    c.issues_opened,
    c.issues_closed,
    CURRENT_TIMESTAMP AS sqlmesh_updated_at
FROM combined c
LEFT JOIN repos r ON c.repo_full_name = r.repo_full_name
WHERE r.repo_key IS NOT NULL
