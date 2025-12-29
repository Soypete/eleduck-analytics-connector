MODEL (
    name staging.stg_stripe__customers,
    kind VIEW,
    cron '@daily',
    grain customer_id,
    description 'Stripe customer records'
);

SELECT
    id AS customer_id,

    -- Contact info
    email,
    name,
    phone,
    description,

    -- Address
    address_city AS city,
    address_country AS country,
    address_postal_code AS postal_code,

    -- Financial
    currency,
    COALESCE(balance::INT, 0) AS balance_cents,
    (COALESCE(balance::INT, 0)::DECIMAL / 100.0) AS balance_dollars,
    delinquent::BOOLEAN AS is_delinquent,

    -- Metadata
    default_source,

    -- Timestamps
    TO_TIMESTAMP(created) AS created_at,

    _airbyte_extracted_at AS extracted_at

FROM raw.customers
WHERE id IS NOT NULL
