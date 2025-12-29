with source as (
    select * from {{ source('notion', 'pages') }}
),

renamed as (
    select
        -- IDs
        id as page_id,
        parent_database_id as parent_id,
        parent_type,

        -- Content
        title,
        icon_type,
        icon_emoji,
        cover_type,
        cover_external_url as cover_url,

        -- Timestamps
        created_time::timestamp as created_at,
        last_edited_time::timestamp as last_edited_at,

        -- Users
        created_by_id,
        last_edited_by_id,

        -- Status
        archived as is_archived,
        in_trash as is_in_trash,

        -- URLs
        url as page_url,
        public_url,

        -- Metadata
        _airbyte_extracted_at as extracted_at

    from source
    where id is not null
)

select * from renamed
