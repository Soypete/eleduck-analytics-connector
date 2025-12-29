MODEL (
    name analytics.dim_content,
    kind FULL,
    cron '@daily',
    grain content_key,
    description 'Unified content dimension across platforms'
);

WITH content AS (
    SELECT * FROM staging.int_content_unified
),

with_dimensions AS (
    SELECT
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
        TO_CHAR(c.published_at, 'YYYYMMDD')::INTEGER AS published_date_key,
        CURRENT_TIMESTAMP AS sqlmesh_updated_at
    FROM content c
    LEFT JOIN analytics.dim_platform p ON c.platform = p.platform_id
)

SELECT * FROM with_dimensions
