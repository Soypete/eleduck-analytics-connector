with source as (
    select * from {{ source('github', 'repositories') }}
),

renamed as (
    select
        -- IDs
        id as repo_id,
        node_id,
        name as repo_name,
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
        git_url,
        ssh_url,
        clone_url,

        -- Flags
        private as is_private,
        fork as is_fork,
        archived as is_archived,
        disabled as is_disabled,
        has_issues,
        has_projects,
        has_wiki,
        has_pages,
        has_downloads,
        has_discussions,

        -- Metrics
        coalesce(stargazers_count::int, 0) as stargazers_count,
        coalesce(forks_count::int, 0) as forks_count,
        coalesce(watchers_count::int, 0) as watchers_count,
        coalesce(open_issues_count::int, 0) as open_issues_count,
        coalesce(size::int, 0) as size_kb,

        -- Default branch
        default_branch,

        -- License
        license_name,
        license_spdx_id,

        -- Timestamps
        created_at::timestamp as created_at,
        updated_at::timestamp as updated_at,
        pushed_at::timestamp as pushed_at,

        -- Metadata
        _airbyte_extracted_at as extracted_at

    from source
    where id is not null
)

select * from renamed
