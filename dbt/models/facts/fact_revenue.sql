{{
    config(
        materialized='incremental',
        unique_key='charge_id',
        incremental_strategy='merge'
    )
}}

with charges as (
    select
        charge_id,
        to_char(created_at, 'YYYYMMDD')::integer as date_key,
        customer_id,
        'stripe_charge' as revenue_source,
        amount_cents,
        amount_dollars,
        currency,
        status,
        is_paid,
        is_refunded,
        description as product_name,
        invoice_id,
        created_at,
        extracted_at
    from {{ ref('stg_stripe__charges') }}
    where is_paid = true
    {% if is_incremental() %}
    and created_at > (select coalesce(max(created_at), '2020-01-01') from {{ this }})
    {% endif %}
),

final as (
    select
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
        current_timestamp as dbt_updated_at
    from charges
)

select * from final
