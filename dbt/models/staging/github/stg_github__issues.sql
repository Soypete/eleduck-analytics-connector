with source as (
    select * from {{ source('github', 'issues') }}
),

renamed as (
    select
        id as issue_id,
        number as issue_number,
        repository as repo_full_name,

        -- Content
        title,
        body,
        state,

        -- User
        user_login as author_login,
        user_id as author_id,

        -- Assignees
        assignee_login,
        assignees,

        -- Labels
        labels,

        -- Milestone
        milestone_title,
        milestone_number,

        -- Timestamps
        created_at::timestamp as created_at,
        updated_at::timestamp as updated_at,
        closed_at::timestamp as closed_at,

        -- Stats
        coalesce(comments::int, 0) as comment_count,

        -- Flags
        locked as is_locked,
        pull_request is not null as is_pull_request,

        -- URL
        html_url as issue_url,

        _airbyte_extracted_at as extracted_at

    from source
    where id is not null
)

select * from renamed
