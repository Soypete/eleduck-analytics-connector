MODEL (
    name staging.stg_notion__pages,
    kind VIEW,
    cron '@daily',
    grain page_id,
    description 'Notion page records'
);

SELECT
    -- IDs
    id AS page_id,

    -- Content
    properties_title_title_0_plain_text AS title,

    -- Parent info
    parent_type,
    COALESCE(parent_database_id, parent_page_id, parent_workspace) AS parent_id,

    -- User info
    created_by_id AS created_by,
    last_edited_by_id AS last_edited_by,

    -- Timestamps
    created_time::TIMESTAMP AS created_at,
    last_edited_time::TIMESTAMP AS last_edited_at,

    -- Status
    archived::BOOLEAN AS is_archived,

    -- URL
    url AS page_url,

    _airbyte_extracted_at AS extracted_at

FROM raw.pages
WHERE id IS NOT NULL
