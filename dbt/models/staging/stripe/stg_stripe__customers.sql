with source as (
    select * from {{ source('stripe', 'customers') }}
),

renamed as (
    select
        id as customer_id,

        -- Contact info
        email,
        name,
        phone,
        description,

        -- Address
        address_city,
        address_country,
        address_line1,
        address_line2,
        address_postal_code,
        address_state,

        -- Financial
        currency,
        coalesce(balance::int, 0) as balance_cents,
        {{ cents_to_dollars('coalesce(balance::int, 0)') }} as balance_dollars,
        delinquent as is_delinquent,

        -- Default payment
        default_source,
        invoice_prefix,

        -- Timestamps
        to_timestamp(created) as created_at,

        _airbyte_extracted_at as extracted_at

    from source
    where id is not null
)

select * from renamed
