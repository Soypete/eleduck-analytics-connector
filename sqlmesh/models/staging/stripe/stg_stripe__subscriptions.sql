MODEL (
    name staging.stg_stripe__subscriptions,
    kind VIEW,
    cron '@daily',
    grain subscription_id,
    description 'Stripe subscription records'
);

SELECT
    id AS subscription_id,

    -- Customer
    customer AS customer_id,

    -- Status
    status,

    -- Plan details
    plan_id,
    plan_nickname AS plan_name,
    plan_amount AS amount_cents,
    (plan_amount::DECIMAL / 100.0) AS amount_dollars,
    plan_currency AS currency,
    plan_interval AS interval,
    plan_interval_count AS interval_count,

    -- Billing
    TO_TIMESTAMP(current_period_start) AS current_period_start,
    TO_TIMESTAMP(current_period_end) AS current_period_end,

    -- Cancellation
    cancel_at_period_end::BOOLEAN AS cancel_at_period_end,
    TO_TIMESTAMP(NULLIF(canceled_at, 0)) AS canceled_at,
    TO_TIMESTAMP(NULLIF(ended_at, 0)) AS ended_at,

    -- Timestamps
    TO_TIMESTAMP(created) AS created_at,

    _airbyte_extracted_at AS extracted_at

FROM raw.subscriptions
WHERE id IS NOT NULL
