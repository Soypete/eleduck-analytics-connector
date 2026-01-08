{{
    config(
        materialized='view',
        tags=['intermediate']
    )
}}

{#
    This model unifies content from both Spotify (podcast episodes) and YouTube (videos)
    using a manual mapping seed to link corresponding content across platforms.

    The mapping allows us to track the same content piece across multiple distribution channels.
#}

with episodes as (
    select * from {{ ref('stg_spotify__episodes') }}
),

videos as (
    select * from {{ ref('stg_youtube__videos') }}
),

mapping as (
    -- Manual mapping between episode_id and video_id
    select * from {{ ref('seed_content_mapping') }}
),

-- Join episodes to mapping
episode_content as (
    select
        m.content_id,
        e.episode_id,
        null::varchar as video_id,
        e.title,
        e.published_date,
        e.duration_seconds,
        'spotify_only' as content_source
    from episodes e
    left join mapping m on e.episode_id = m.episode_id
    where m.video_id is null or m.video_id = ''
),

-- Join videos to mapping
video_content as (
    select
        m.content_id,
        null::varchar as episode_id,
        v.video_id,
        v.title,
        v.published_date,
        v.duration_seconds,
        'youtube_only' as content_source
    from videos v
    left join mapping m on v.video_id = m.video_id
    where m.episode_id is null or m.episode_id = ''
),

-- Unified content with both platforms
mapped_content as (
    select
        m.content_id,
        e.episode_id,
        v.video_id,
        coalesce(e.title, v.title) as title,
        coalesce(e.published_date, v.published_date) as published_date,
        coalesce(e.duration_seconds, v.duration_seconds) as duration_seconds,
        case
            when e.episode_id is not null and v.video_id is not null then 'both_platforms'
            when e.episode_id is not null then 'spotify_only'
            when v.video_id is not null then 'youtube_only'
        end as content_source
    from mapping m
    left join episodes e on m.episode_id = e.episode_id
    left join videos v on m.video_id = v.video_id
    where m.content_id is not null
),

-- Combine all content
unified as (
    select * from mapped_content
    union all
    select * from episode_content where content_id is null
    union all
    select * from video_content where content_id is null
),

-- Generate content_id for unmapped content
final as (
    select
        coalesce(
            content_id,
            'ep-' || coalesce(episode_id, video_id)
        ) as content_id,
        episode_id,
        video_id,
        title,
        published_date,
        duration_seconds,
        content_source
    from unified
)

select * from final
