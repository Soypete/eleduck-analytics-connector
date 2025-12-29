with source as (
    select * from {{ source('linkedin', 'page_stats') }}
),

renamed as (
    select
        -- IDs
        organization_id as page_id,
        organization_name as page_name,

        -- Metrics
        coalesce(total_follower_count::int, 0) as follower_count,
        coalesce(total_page_statistics_views_all_page_views::int, 0) as page_views,
        coalesce(total_page_statistics_views_all_unique_page_views::int, 0) as unique_visitors,

        -- Follower changes
        coalesce(follower_gains_organic_follower_count::int, 0) as organic_followers_gained,
        coalesce(follower_gains_paid_follower_count::int, 0) as paid_followers_gained,

        -- Timestamps
        date::date as metric_date,

        -- Metadata
        _airbyte_extracted_at as extracted_at

    from source
    where organization_id is not null
)

select * from renamed
