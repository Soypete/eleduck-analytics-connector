with source as (
    select * from {{ source('stripe', 'charges') }}
),

renamed as (
    select
        id as charge_id,

        -- Customer
        customer as customer_id,

        -- Amount
        amount as amount_cents,
        {{ cents_to_dollars('amount') }} as amount_dollars,
        currency,

        -- Status
        status,
        paid as is_paid,
        refunded as is_refunded,

        -- Metadata
        description,
        receipt_email,

        -- Invoice reference
        invoice as invoice_id,

        -- Timestamps
        to_timestamp(created) as created_at,

        -- Failure info
        failure_code,
        failure_message,

        _airbyte_extracted_at as extracted_at

    from source
    where id is not null
)

select * from renamed
