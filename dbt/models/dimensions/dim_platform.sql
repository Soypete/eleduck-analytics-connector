{{
    config(
        materialized='table'
    )
}}

with platform_data as (
    select
        {{ generate_surrogate_key(['platform_id']) }} as platform_key,
        platform_id,
        platform_name,
        platform_category,
        platform_url
    from {{ ref('platform_lookup') }}
)

select * from platform_data
