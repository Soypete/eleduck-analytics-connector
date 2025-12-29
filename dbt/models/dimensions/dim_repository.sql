{{
    config(
        materialized='table'
    )
}}

with repos as (
    select * from {{ ref('stg_github__repos') }}
),

final as (
    select
        {{ generate_surrogate_key(['repo_id']) }} as repo_key,
        repo_id,
        repo_name,
        full_name as repo_full_name,
        owner_login as owner,
        description,
        language as primary_language,
        html_url as repo_url,
        is_private,
        is_fork,
        created_at,
        updated_at,
        current_timestamp as dbt_updated_at
    from repos
)

select * from final
