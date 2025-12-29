{{
    config(
        materialized='ephemeral'
    )
}}

with youtube_content as (
    select
        'youtube' as platform,
        video_id as native_id,
        'video' as content_type,
        title,
        description,
        video_url as url,
        thumbnail_url,
        published_at,
        extracted_at
    from {{ ref('stg_youtube__videos') }}
),

twitch_content as (
    select
        'twitch' as platform,
        stream_id as native_id,
        'stream' as content_type,
        title,
        null as description,
        stream_url as url,
        thumbnail_url,
        started_at as published_at,
        extracted_at
    from {{ ref('stg_twitch__streams') }}
),

twitter_content as (
    select
        'twitter' as platform,
        tweet_id as native_id,
        'tweet' as content_type,
        text as title,
        null as description,
        tweet_url as url,
        null as thumbnail_url,
        created_at as published_at,
        extracted_at
    from {{ ref('stg_twitter__tweets') }}
),

linkedin_content as (
    select
        'linkedin' as platform,
        post_id as native_id,
        'post' as content_type,
        title,
        description,
        post_url as url,
        null as thumbnail_url,
        published_at,
        extracted_at
    from {{ ref('stg_linkedin__posts') }}
),

unioned as (
    select * from youtube_content
    union all
    select * from twitch_content
    union all
    select * from twitter_content
    union all
    select * from linkedin_content
)

select
    {{ generate_surrogate_key(['platform', 'native_id']) }} as content_key,
    *
from unioned
