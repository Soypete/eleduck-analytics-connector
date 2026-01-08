{{
    config(
        materialized='table',
        tags=['marts']
    )
}}

{#
    Content Performance Mart
    Aggregates total performance metrics for each content piece across Spotify and YouTube.
    Used for top-level content rankings and performance comparisons.
#}

with content as (
    select * from {{ ref('int_content_unified') }}
),

-- Aggregate Spotify streams per episode
spotify_metrics as (
    select
        episode_id,
        sum(streams) as total_streams,
        sum(starts) as total_starts,
        sum(unique_listeners) as total_unique_listeners,
        avg(avg_listen_seconds) as avg_listen_seconds
    from {{ ref('stg_spotify__daily_performance') }}
    group by 1
),

-- Aggregate YouTube metrics per video
youtube_metrics as (
    select
        video_id,
        sum(views) as total_views,
        sum(watch_time_minutes) as total_watch_minutes,
        sum(likes) as total_likes,
        sum(comments) as total_comments,
        avg(avg_view_seconds) as avg_view_seconds
    from {{ ref('stg_youtube__daily_stats') }}
    group by 1
),

final as (
    select
        c.content_id,
        c.title,
        c.published_date,
        c.duration_seconds,
        c.content_source,
        c.episode_id,
        c.video_id,

        -- Spotify metrics
        coalesce(s.total_streams, 0) as total_streams,
        coalesce(s.total_starts, 0) as total_starts,
        coalesce(s.total_unique_listeners, 0) as total_unique_listeners,
        s.avg_listen_seconds,

        -- YouTube metrics
        coalesce(y.total_views, 0) as total_views,
        coalesce(y.total_watch_minutes, 0) as total_watch_minutes,
        coalesce(y.total_likes, 0) as total_likes,
        coalesce(y.total_comments, 0) as total_comments,
        y.avg_view_seconds,

        -- Combined metrics
        coalesce(s.total_streams, 0) + coalesce(y.total_views, 0) as total_consumption,

        -- Calculated engagement rates
        case
            when y.total_views > 0 then y.total_likes::decimal / y.total_views
            else 0
        end as youtube_like_rate,

        case
            when s.total_starts > 0 then s.total_streams::decimal / s.total_starts
            else 0
        end as spotify_completion_rate,

        current_timestamp as _dbt_updated_at

    from content c
    left join spotify_metrics s on c.episode_id = s.episode_id
    left join youtube_metrics y on c.video_id = y.video_id
)

select * from final
