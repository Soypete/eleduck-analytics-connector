with source as (
    select * from {{ source('youtube', 'video_metrics') }}
),

renamed as (
    select
        video_id,
        date::date as metric_date,

        -- Views
        coalesce(views::bigint, 0) as views,
        coalesce(estimated_minutes_watched::bigint, 0) * 60 as watch_time_seconds,

        -- Engagement
        coalesce(likes::bigint, 0) as likes,
        coalesce(comments::bigint, 0) as comments,
        coalesce(shares::bigint, 0) as shares,
        coalesce(dislikes::bigint, 0) as dislikes,

        -- Calculated
        {{ safe_divide('coalesce(estimated_minutes_watched::bigint, 0) * 60', 'coalesce(views::bigint, 0)') }} as avg_view_duration_seconds,

        -- Subscribers
        coalesce(subscribers_gained::int, 0) as subscribers_gained,
        coalesce(subscribers_lost::int, 0) as subscribers_lost,

        _airbyte_extracted_at as extracted_at

    from source
    where video_id is not null and date is not null
)

select * from renamed
