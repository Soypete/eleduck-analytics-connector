with source as (
    select * from {{ source('twitter', 'user_metrics') }}
),

renamed as (
    select
        -- IDs
        id as user_id,
        username,
        name,

        -- Profile
        description as bio,
        location,
        url as profile_url,
        profile_image_url,
        verified as is_verified,

        -- Metrics
        coalesce(public_metrics_followers_count::int, 0) as followers_count,
        coalesce(public_metrics_following_count::int, 0) as following_count,
        coalesce(public_metrics_tweet_count::int, 0) as tweet_count,
        coalesce(public_metrics_listed_count::int, 0) as listed_count,

        -- Timestamps
        created_at::timestamp as account_created_at,
        date::date as metric_date,

        -- Metadata
        _airbyte_extracted_at as extracted_at

    from source
    where id is not null
)

select * from renamed
