MODEL (
    name staging.stg_github__issues,
    kind VIEW,
    cron '@daily',
    grain issue_id,
    description 'GitHub issue records'
);

SELECT
    id AS issue_id,
    number AS issue_number,
    repository AS repo_full_name,

    -- Content
    title,
    body,
    state,

    -- User
    user_login AS author_login,
    user_id AS author_id,

    -- Labels and assignees
    labels,
    assignees,

    -- Timestamps
    created_at::TIMESTAMP AS created_at,
    updated_at::TIMESTAMP AS updated_at,
    closed_at::TIMESTAMP AS closed_at,

    -- Metrics
    COALESCE(comments::INT, 0) AS comment_count,

    -- PRs are also returned as issues, filter them out
    pull_request IS NOT NULL AS is_pull_request,

    -- URL
    html_url AS issue_url,

    _airbyte_extracted_at AS extracted_at

FROM raw.issues
WHERE id IS NOT NULL
  AND pull_request IS NULL  -- Exclude pull requests
