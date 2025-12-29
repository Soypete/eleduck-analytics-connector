{{
    config(
        materialized='ephemeral'
    )
}}

with youtube_daily as (
    select
        metric_date,
        'youtube' as platform,
        sum(views) as total_views,
        sum(likes + comments + shares) as total_engagement,
        count(distinct video_id) as content_count
    from {{ ref('stg_youtube__video_metrics') }}
    group by 1, 2
),

twitter_daily as (
    select
        created_at::date as metric_date,
        'twitter' as platform,
        sum(impression_count) as total_views,
        sum(like_count + reply_count + retweet_count + quote_count) as total_engagement,
        count(distinct tweet_id) as content_count
    from {{ ref('stg_twitter__tweets') }}
    group by 1, 2
),

linkedin_daily as (
    select
        published_at::date as metric_date,
        'linkedin' as platform,
        sum(impression_count) as total_views,
        sum(like_count + comment_count + share_count) as total_engagement,
        count(distinct post_id) as content_count
    from {{ ref('stg_linkedin__posts') }}
    group by 1, 2
),

twitch_daily as (
    select
        started_at::date as metric_date,
        'twitch' as platform,
        sum(viewer_count) as total_views,
        0 as total_engagement,
        count(distinct stream_id) as content_count
    from {{ ref('stg_twitch__streams') }}
    group by 1, 2
),

unioned as (
    select * from youtube_daily
    union all
    select * from twitter_daily
    union all
    select * from linkedin_daily
    union all
    select * from twitch_daily
),

final as (
    select
        metric_date,
        platform,
        total_views,
        total_engagement,
        content_count,
        {{ safe_divide('total_engagement', 'total_views') }} as avg_engagement_rate
    from unioned
    where metric_date is not null
)

select * from final
