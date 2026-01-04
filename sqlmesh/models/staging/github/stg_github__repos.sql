MODEL (
    name staging.stg_github__repos,
    kind VIEW,
    cron '@daily',
    grain repo_id,
    description 'GitHub repository metadata'
);

SELECT
    -- IDs
    id AS repo_id,
    name AS repo_name,
    full_name,
    owner_login,
    owner_id,

    -- Description
    description,
    homepage,
    language,
    topics,

    -- URLs
    html_url,
    clone_url,
    ssh_url,

    -- Flags
    private::BOOLEAN AS is_private,
    fork::BOOLEAN AS is_fork,
    archived::BOOLEAN AS is_archived,
    disabled::BOOLEAN AS is_disabled,
    has_issues::BOOLEAN AS has_issues_enabled,
    has_wiki::BOOLEAN AS has_wiki_enabled,
    has_pages::BOOLEAN AS has_pages_enabled,
    has_downloads::BOOLEAN AS has_downloads_enabled,

    -- Metrics
    COALESCE(stargazers_count::INT, 0) AS stargazers_count,
    COALESCE(watchers_count::INT, 0) AS watchers_count,
    COALESCE(forks_count::INT, 0) AS forks_count,
    COALESCE(open_issues_count::INT, 0) AS open_issues_count,
    COALESCE(size::INT, 0) AS size_kb,

    -- License
    license_key,
    license_name,

    -- Timestamps
    created_at::TIMESTAMP AS created_at,
    updated_at::TIMESTAMP AS updated_at,
    pushed_at::TIMESTAMP AS pushed_at,

    _airbyte_extracted_at AS extracted_at

FROM raw.repositories
WHERE id IS NOT NULL
