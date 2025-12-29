{{
    config(
        materialized='incremental',
        unique_key=['date_key', 'content_key'],
        incremental_strategy='merge',
        on_schema_change='sync_all_columns'
    )
}}

with youtube_metrics as (
    select
        to_char(metric_date, 'YYYYMMDD')::integer as date_key,
        {{ generate_surrogate_key(["'youtube'", 'video_id']) }} as content_key,
        'youtube' as platform,
        views,
        likes,
        comments,
        shares,
        0 as saves,
        watch_time_seconds,
        avg_view_duration_seconds,
        subscribers_gained as followers_gained,
        extracted_at
    from {{ ref('stg_youtube__video_metrics') }}
    {% if is_incremental() %}
    where metric_date > (select coalesce(max(d.full_date), '2020-01-01') from {{ this }} t join {{ ref('dim_date') }} d on t.date_key = d.date_key)
    {% endif %}
),

twitter_metrics as (
    select
        to_char(created_at::date, 'YYYYMMDD')::integer as date_key,
        {{ generate_surrogate_key(["'twitter'", 'tweet_id']) }} as content_key,
        'twitter' as platform,
        impression_count as views,
        like_count as likes,
        reply_count as comments,
        retweet_count + quote_count as shares,
        0 as saves,
        0 as watch_time_seconds,
        0 as avg_view_duration_seconds,
        0 as followers_gained,
        extracted_at
    from {{ ref('stg_twitter__tweets') }}
    {% if is_incremental() %}
    where created_at::date > (select coalesce(max(d.full_date), '2020-01-01') from {{ this }} t join {{ ref('dim_date') }} d on t.date_key = d.date_key)
    {% endif %}
),

linkedin_metrics as (
    select
        to_char(published_at::date, 'YYYYMMDD')::integer as date_key,
        {{ generate_surrogate_key(["'linkedin'", 'post_id']) }} as content_key,
        'linkedin' as platform,
        impression_count as views,
        like_count as likes,
        comment_count as comments,
        share_count as shares,
        0 as saves,
        0 as watch_time_seconds,
        0 as avg_view_duration_seconds,
        0 as followers_gained,
        extracted_at
    from {{ ref('stg_linkedin__posts') }}
    {% if is_incremental() %}
    where published_at::date > (select coalesce(max(d.full_date), '2020-01-01') from {{ this }} t join {{ ref('dim_date') }} d on t.date_key = d.date_key)
    {% endif %}
),

twitch_metrics as (
    select
        to_char(started_at::date, 'YYYYMMDD')::integer as date_key,
        {{ generate_surrogate_key(["'twitch'", 'stream_id']) }} as content_key,
        'twitch' as platform,
        viewer_count as views,
        0 as likes,
        0 as comments,
        0 as shares,
        0 as saves,
        0 as watch_time_seconds,
        0 as avg_view_duration_seconds,
        0 as followers_gained,
        extracted_at
    from {{ ref('stg_twitch__streams') }}
    {% if is_incremental() %}
    where started_at::date > (select coalesce(max(d.full_date), '2020-01-01') from {{ this }} t join {{ ref('dim_date') }} d on t.date_key = d.date_key)
    {% endif %}
),

unioned as (
    select * from youtube_metrics
    union all
    select * from twitter_metrics
    union all
    select * from linkedin_metrics
    union all
    select * from twitch_metrics
),

aggregated as (
    select
        date_key,
        content_key,
        max(platform) as platform,
        sum(views) as views,
        sum(likes) as likes,
        sum(comments) as comments,
        sum(shares) as shares,
        sum(saves) as saves,
        sum(watch_time_seconds) as watch_time_seconds,
        avg(avg_view_duration_seconds) as avg_view_duration_seconds,
        sum(followers_gained) as followers_gained,
        current_timestamp as dbt_updated_at
    from unioned
    group by 1, 2
)

select * from aggregated
