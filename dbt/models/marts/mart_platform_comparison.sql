{{
    config(
        materialized='table',
        tags=['marts']
    )
}}

{#
    Platform Comparison Mart
    Compares performance metrics between Spotify and YouTube.
    Used for platform-level analysis and audience insights.
#}

with spotify_totals as (
    select
        'spotify' as platform,
        sum(streams) as total_consumption,
        sum(starts) as total_starts,
        sum(unique_listeners) as total_reach,
        count(distinct episode_id) as content_count,
        min(metric_date) as first_date,
        max(metric_date) as last_date
    from {{ ref('stg_spotify__daily_performance') }}
),

youtube_totals as (
    select
        'youtube' as platform,
        sum(views) as total_consumption,
        null::bigint as total_starts,
        null::bigint as total_reach,
        count(distinct video_id) as content_count,
        min(metric_date) as first_date,
        max(metric_date) as last_date
    from {{ ref('stg_youtube__daily_stats') }}
),

-- Get show-level stats
spotify_show as (
    select
        max(followers) as followers,
        max(total_streams) as cumulative_streams
    from {{ ref('stg_spotify__show_stats') }}
),

combined as (
    select * from spotify_totals
    union all
    select * from youtube_totals
),

final as (
    select
        c.platform,
        c.total_consumption,
        c.total_starts,
        c.total_reach,
        c.content_count,
        c.first_date,
        c.last_date,

        -- Calculate days active
        c.last_date - c.first_date + 1 as days_active,

        -- Daily average consumption
        case
            when c.last_date - c.first_date + 1 > 0
            then c.total_consumption::decimal / (c.last_date - c.first_date + 1)
            else 0
        end as avg_daily_consumption,

        -- Spotify-specific: followers from show stats
        case
            when c.platform = 'spotify' then (select followers from spotify_show)
            else null
        end as followers,

        current_timestamp as _dbt_updated_at

    from combined c
)

select * from final
