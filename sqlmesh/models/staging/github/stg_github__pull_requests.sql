MODEL (
    name staging.stg_github__pull_requests,
    kind VIEW,
    cron '@daily',
    grain pr_id,
    description 'GitHub pull request records'
);

SELECT
    id AS pr_id,
    number AS pr_number,
    repository AS repo_full_name,

    -- Content
    title,
    body AS description,
    state,

    -- User
    user_login AS author_login,
    user_id AS author_id,

    -- Timestamps
    created_at::TIMESTAMP AS created_at,
    updated_at::TIMESTAMP AS updated_at,
    merged_at::TIMESTAMP AS merged_at,
    closed_at::TIMESTAMP AS closed_at,

    -- Stats
    COALESCE(additions::INT, 0) AS lines_added,
    COALESCE(deletions::INT, 0) AS lines_deleted,
    COALESCE(changed_files::INT, 0) AS files_changed,
    COALESCE(commits::INT, 0) AS commit_count,
    COALESCE(comments::INT, 0) AS comment_count,

    -- Flags
    merged::BOOLEAN AS is_merged,
    draft::BOOLEAN AS is_draft,

    -- URL
    html_url AS pr_url,

    _airbyte_extracted_at AS extracted_at

FROM raw.pull_requests
WHERE id IS NOT NULL
