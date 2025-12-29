with source as (
    select * from {{ source('stripe', 'subscriptions') }}
),

renamed as (
    select
        id as subscription_id,

        -- Customer
        customer as customer_id,

        -- Status
        status,

        -- Plan details
        plan_id,
        plan_amount as plan_amount_cents,
        {{ cents_to_dollars('plan_amount') }} as plan_amount_dollars,
        plan_interval,
        plan_interval_count,
        plan_nickname as plan_name,

        -- Billing
        billing_cycle_anchor::timestamp as billing_cycle_anchor,
        to_timestamp(current_period_start) as current_period_start,
        to_timestamp(current_period_end) as current_period_end,

        -- Cancellation
        cancel_at_period_end,
        canceled_at::timestamp as canceled_at,
        ended_at::timestamp as ended_at,

        -- Trial
        trial_start::timestamp as trial_start,
        trial_end::timestamp as trial_end,

        -- Quantities
        coalesce(quantity::int, 1) as quantity,

        -- Timestamps
        to_timestamp(created) as created_at,

        _airbyte_extracted_at as extracted_at

    from source
    where id is not null
)

select * from renamed
