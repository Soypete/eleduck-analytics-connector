with source as (
    select * from {{ source('twitch', 'followers') }}
),

renamed as (
    select
        -- IDs
        user_id as follower_id,
        user_login as follower_login,
        user_name as follower_name,

        -- Timestamps
        followed_at::timestamp as followed_at,

        -- Metadata
        _airbyte_extracted_at as extracted_at

    from source
    where user_id is not null
)

select * from renamed
