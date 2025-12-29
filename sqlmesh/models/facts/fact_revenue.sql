MODEL (
    name analytics.fact_revenue,
    kind INCREMENTAL_BY_TIME_RANGE (
        time_column created_at,
        batch_size 30
    ),
    cron '@daily',
    grain charge_id,
    description 'Revenue transactions from Stripe'
);

WITH charges AS (
    SELECT
        charge_id,
        TO_CHAR(created_at, 'YYYYMMDD')::INTEGER AS date_key,
        customer_id,
        'stripe_charge' AS revenue_source,
        amount_cents,
        amount_dollars,
        currency,
        status,
        is_paid,
        is_refunded,
        description AS product_name,
        invoice_id,
        created_at,
        extracted_at
    FROM staging.stg_stripe__charges
    WHERE is_paid = TRUE
      AND created_at BETWEEN @start_date AND @end_date
)

SELECT
    charge_id,
    date_key,
    customer_id,
    revenue_source,
    amount_cents,
    amount_dollars,
    currency,
    status,
    is_refunded,
    product_name,
    invoice_id,
    created_at,
    CURRENT_TIMESTAMP AS sqlmesh_updated_at
FROM charges
