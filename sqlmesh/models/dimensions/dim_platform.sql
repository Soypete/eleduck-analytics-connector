MODEL (
    name analytics.dim_platform,
    kind FULL,
    cron '@daily',
    grain platform_key,
    description 'Platform master data dimension'
);

SELECT
    MD5(COALESCE(CAST(platform_id AS TEXT), '')) AS platform_key,
    platform_id,
    platform_name,
    platform_category,
    platform_url
FROM analytics.seed_platform_lookup
