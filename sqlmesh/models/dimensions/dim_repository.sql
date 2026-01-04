MODEL (
    name analytics.dim_repository,
    kind FULL,
    cron '@daily',
    grain repo_key,
    description 'GitHub repository dimension'
);

WITH repos AS (
    SELECT * FROM staging.stg_github__repos
)

SELECT
    MD5(COALESCE(CAST(repo_id AS TEXT), '')) AS repo_key,
    repo_id,
    repo_name,
    full_name AS repo_full_name,
    owner_login AS owner,
    description,
    language AS primary_language,
    html_url AS repo_url,
    is_private,
    is_fork,
    created_at,
    updated_at,
    CURRENT_TIMESTAMP AS sqlmesh_updated_at
FROM repos
