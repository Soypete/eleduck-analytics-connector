with source as (
    select * from {{ source('github', 'pull_requests') }}
),

renamed as (
    select
        id as pr_id,
        number as pr_number,
        repository as repo_full_name,

        -- Content
        title,
        body as description,
        state,

        -- User
        user_login as author_login,
        user_id as author_id,

        -- Timestamps
        created_at::timestamp as created_at,
        updated_at::timestamp as updated_at,
        merged_at::timestamp as merged_at,
        closed_at::timestamp as closed_at,

        -- Stats
        coalesce(additions::int, 0) as lines_added,
        coalesce(deletions::int, 0) as lines_deleted,
        coalesce(changed_files::int, 0) as files_changed,
        coalesce(commits::int, 0) as commit_count,
        coalesce(comments::int, 0) as comment_count,

        -- Flags
        merged as is_merged,
        draft as is_draft,

        -- URL
        html_url as pr_url,

        _airbyte_extracted_at as extracted_at

    from source
    where id is not null
)

select * from renamed
