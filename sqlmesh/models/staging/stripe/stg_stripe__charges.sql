MODEL (
    name staging.stg_stripe__charges,
    kind VIEW,
    cron '@daily',
    grain charge_id,
    description 'Stripe payment charges'
);

SELECT
    id AS charge_id,

    -- Customer
    customer AS customer_id,

    -- Amount
    amount AS amount_cents,
    (amount::DECIMAL / 100.0) AS amount_dollars,
    currency,

    -- Status
    status,
    paid::BOOLEAN AS is_paid,
    refunded::BOOLEAN AS is_refunded,

    -- Metadata
    description,
    receipt_email,

    -- Invoice reference
    invoice AS invoice_id,

    -- Timestamps
    TO_TIMESTAMP(created) AS created_at,

    -- Failure info
    failure_code,
    failure_message,

    _airbyte_extracted_at AS extracted_at

FROM raw.charges
WHERE id IS NOT NULL
