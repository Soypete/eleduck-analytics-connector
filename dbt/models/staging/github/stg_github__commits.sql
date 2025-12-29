with source as (
    select * from {{ source('github', 'commits') }}
),

renamed as (
    select
        sha as commit_sha,
        repository as repo_full_name,

        -- Author info
        commit_author_name as author_name,
        commit_author_email as author_email,
        commit_author_date::timestamp as authored_at,

        -- Committer info
        commit_committer_name as committer_name,
        commit_committer_date::timestamp as committed_at,

        -- Content
        commit_message as message,

        -- Stats
        coalesce(stats_additions::int, 0) as lines_added,
        coalesce(stats_deletions::int, 0) as lines_deleted,
        coalesce(stats_total::int, 0) as lines_changed,

        -- URL
        html_url as commit_url,

        _airbyte_extracted_at as extracted_at

    from source
    where sha is not null
)

select * from renamed
