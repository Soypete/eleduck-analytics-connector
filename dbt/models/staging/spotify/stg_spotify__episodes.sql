{{
    config(
        materialized='view',
        tags=['spotify', 'staging']
    )
}}

with source as (
    select * from {{ source('raw_spotify', 'spotify_episodes') }}
),

renamed as (
    select
        id as episode_id,
        name as title,
        release_date::date as published_date,
        -- Convert milliseconds to seconds
        (duration_ms / 1000)::int as duration_seconds,
        description,
        explicit as is_explicit,
        -- Spotify-specific fields
        uri as spotify_uri,
        external_urls->>'spotify' as spotify_url,
        -- Metadata for tracking
        current_timestamp as _dbt_loaded_at
    from source
)

select * from renamed
