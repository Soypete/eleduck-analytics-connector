{{
    config(
        materialized='incremental',
        unique_key=['date_key', 'repo_key'],
        incremental_strategy='merge'
    )
}}

with commits as (
    select
        to_char(committed_at::date, 'YYYYMMDD')::integer as date_key,
        repo_full_name,
        count(*) as commits,
        sum(lines_added) as lines_added,
        sum(lines_deleted) as lines_deleted,
        count(distinct author_email) as unique_contributors
    from {{ ref('stg_github__commits') }}
    {% if is_incremental() %}
    where committed_at::date > (select coalesce(max(d.full_date), '2020-01-01') from {{ this }} t join {{ ref('dim_date') }} d on t.date_key = d.date_key)
    {% endif %}
    group by 1, 2
),

prs as (
    select
        to_char(created_at::date, 'YYYYMMDD')::integer as date_key,
        repo_full_name,
        count(*) as prs_opened,
        count(case when merged_at is not null then 1 end) as prs_merged,
        count(case when closed_at is not null and merged_at is null then 1 end) as prs_closed
    from {{ ref('stg_github__pull_requests') }}
    {% if is_incremental() %}
    where created_at::date > (select coalesce(max(d.full_date), '2020-01-01') from {{ this }} t join {{ ref('dim_date') }} d on t.date_key = d.date_key)
    {% endif %}
    group by 1, 2
),

issues as (
    select
        to_char(created_at::date, 'YYYYMMDD')::integer as date_key,
        repo_full_name,
        count(*) as issues_opened,
        count(case when closed_at is not null then 1 end) as issues_closed
    from {{ ref('stg_github__issues') }}
    where not is_pull_request
    {% if is_incremental() %}
    and created_at::date > (select coalesce(max(d.full_date), '2020-01-01') from {{ this }} t join {{ ref('dim_date') }} d on t.date_key = d.date_key)
    {% endif %}
    group by 1, 2
),

repos as (
    select
        repo_key,
        repo_full_name
    from {{ ref('dim_repository') }}
),

combined as (
    select
        coalesce(c.date_key, p.date_key, i.date_key) as date_key,
        coalesce(c.repo_full_name, p.repo_full_name, i.repo_full_name) as repo_full_name,
        coalesce(c.commits, 0) as commits,
        coalesce(c.lines_added, 0) as lines_added,
        coalesce(c.lines_deleted, 0) as lines_deleted,
        coalesce(c.unique_contributors, 0) as unique_contributors,
        coalesce(p.prs_opened, 0) as prs_opened,
        coalesce(p.prs_merged, 0) as prs_merged,
        coalesce(p.prs_closed, 0) as prs_closed,
        coalesce(i.issues_opened, 0) as issues_opened,
        coalesce(i.issues_closed, 0) as issues_closed
    from commits c
    full outer join prs p on c.date_key = p.date_key and c.repo_full_name = p.repo_full_name
    full outer join issues i on coalesce(c.date_key, p.date_key) = i.date_key
        and coalesce(c.repo_full_name, p.repo_full_name) = i.repo_full_name
),

final as (
    select
        c.date_key,
        r.repo_key,
        c.commits,
        c.lines_added,
        c.lines_deleted,
        c.unique_contributors,
        c.prs_opened,
        c.prs_merged,
        c.prs_closed,
        c.issues_opened,
        c.issues_closed,
        current_timestamp as dbt_updated_at
    from combined c
    left join repos r on c.repo_full_name = r.repo_full_name
    where r.repo_key is not null
)

select * from final
