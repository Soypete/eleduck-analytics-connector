{{
    config(
        materialized='incremental',
        unique_key='content_key',
        incremental_strategy='merge'
    )
}}

with engagement as (
    select * from {{ ref('fact_daily_engagement') }}
),

content as (
    select * from {{ ref('dim_content') }}
),

aggregated as (
    select
        e.content_key,
        max(e.platform) as platform,
        sum(e.views) as total_views,
        sum(e.likes) as total_likes,
        sum(e.comments) as total_comments,
        sum(e.shares) as total_shares,
        sum(e.watch_time_seconds) as total_watch_time_seconds,
        count(distinct e.date_key) as days_with_data,
        min(d.full_date) as first_metric_date,
        max(d.full_date) as last_metric_date
    from engagement e
    join {{ ref('dim_date') }} d on e.date_key = d.date_key
    group by 1
),

with_content as (
    select
        a.content_key,
        a.platform,
        a.total_views,
        a.total_likes,
        a.total_comments,
        a.total_shares,
        a.total_watch_time_seconds,
        {{ safe_divide('a.total_views', 'a.days_with_data') }} as avg_daily_views,
        extract(day from current_date - c.published_at::date)::int as days_since_published,
        a.first_metric_date,
        a.last_metric_date,
        current_timestamp as dbt_updated_at
    from aggregated a
    left join content c on a.content_key = c.content_key
)

select * from with_content
