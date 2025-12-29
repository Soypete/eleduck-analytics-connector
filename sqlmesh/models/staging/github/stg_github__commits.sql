MODEL (
    name staging.stg_github__commits,
    kind VIEW,
    cron '@daily',
    grain commit_sha,
    description 'GitHub commit records'
);

SELECT
    sha AS commit_sha,
    repository AS repo_full_name,

    -- Author info
    commit_author_name AS author_name,
    commit_author_email AS author_email,
    commit_author_date::TIMESTAMP AS authored_at,

    -- Committer info
    commit_committer_name AS committer_name,
    commit_committer_date::TIMESTAMP AS committed_at,

    -- Content
    commit_message AS message,

    -- Stats
    COALESCE(stats_additions::INT, 0) AS lines_added,
    COALESCE(stats_deletions::INT, 0) AS lines_deleted,
    COALESCE(stats_total::INT, 0) AS lines_changed,

    -- URL
    html_url AS commit_url,

    _airbyte_extracted_at AS extracted_at

FROM raw.commits
WHERE sha IS NOT NULL
