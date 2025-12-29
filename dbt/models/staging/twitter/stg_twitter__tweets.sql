with source as (
    select * from {{ source('twitter', 'tweets') }}
),

renamed as (
    select
        -- IDs
        id as tweet_id,
        author_id,
        conversation_id,
        in_reply_to_user_id,

        -- Content
        text,
        lang as language,

        -- Timestamps
        created_at::timestamp as created_at,

        -- Engagement metrics
        coalesce(public_metrics_retweet_count::int, 0) as retweet_count,
        coalesce(public_metrics_reply_count::int, 0) as reply_count,
        coalesce(public_metrics_like_count::int, 0) as like_count,
        coalesce(public_metrics_quote_count::int, 0) as quote_count,
        coalesce(public_metrics_impression_count::int, 0) as impression_count,

        -- Context
        possibly_sensitive as is_sensitive,

        -- URLs
        'https://twitter.com/i/status/' || id as tweet_url,

        -- Metadata
        _airbyte_extracted_at as extracted_at

    from source
    where id is not null
)

select * from renamed
