{{
    config(
        materialized='table',
        tags=['marts']
    )
}}

{#
    Daily Metrics Mart
    Time-series aggregation of daily metrics across both platforms.
    Used for trend analysis and daily performance dashboards.
#}

with spotify_daily as (
    select
        metric_date,
        sum(streams) as streams,
        sum(starts) as starts,
        sum(unique_listeners) as listeners
    from {{ ref('stg_spotify__daily_performance') }}
    group by 1
),

youtube_daily as (
    select
        metric_date,
        sum(views) as views,
        sum(watch_time_minutes) as watch_minutes,
        sum(likes) as likes,
        sum(comments) as comments
    from {{ ref('stg_youtube__daily_stats') }}
    group by 1
),

-- Generate a complete date spine from both sources
date_spine as (
    select distinct metric_date from spotify_daily
    union
    select distinct metric_date from youtube_daily
),

final as (
    select
        d.metric_date,

        -- Spotify metrics
        coalesce(s.streams, 0) as spotify_streams,
        coalesce(s.starts, 0) as spotify_starts,
        coalesce(s.listeners, 0) as spotify_listeners,

        -- YouTube metrics
        coalesce(y.views, 0) as youtube_views,
        coalesce(y.watch_minutes, 0) as youtube_watch_minutes,
        coalesce(y.likes, 0) as youtube_likes,
        coalesce(y.comments, 0) as youtube_comments,

        -- Combined metrics
        coalesce(s.streams, 0) + coalesce(y.views, 0) as total_consumption,

        -- Day of week for analysis
        extract(dow from d.metric_date) as day_of_week,
        to_char(d.metric_date, 'Day') as day_name,

        current_timestamp as _dbt_updated_at

    from date_spine d
    left join spotify_daily s on d.metric_date = s.metric_date
    left join youtube_daily y on d.metric_date = y.metric_date
)

select * from final
order by metric_date
