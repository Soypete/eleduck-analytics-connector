{{
    config(
        materialized='table'
    )
}}

with content as (
    select * from {{ ref('int_content_unified') }}
),

with_dimensions as (
    select
        c.content_key,
        p.platform_key,
        c.platform,
        c.native_id,
        c.content_type,
        c.title,
        c.description,
        c.url,
        c.thumbnail_url,
        c.published_at,
        to_char(c.published_at, 'YYYYMMDD')::integer as published_date_key,
        current_timestamp as dbt_updated_at
    from content c
    left join {{ ref('dim_platform') }} p on c.platform = p.platform_id
)

select * from with_dimensions
