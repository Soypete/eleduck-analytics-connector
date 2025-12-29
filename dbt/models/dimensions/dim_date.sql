{{
    config(
        materialized='table'
    )
}}

-- Uses the seed file for base data
select
    date_key,
    full_date,
    year,
    quarter,
    month,
    month_name,
    week_of_year,
    day_of_month,
    day_of_week,
    day_name,
    is_weekend::boolean as is_weekend,
    fiscal_year,
    fiscal_quarter,

    -- Calculated fields
    year || '-Q' || quarter as year_quarter,
    year || '-' || lpad(month::text, 2, '0') as year_month,
    fiscal_year || '-FQ' || fiscal_quarter as fiscal_year_quarter

from {{ ref('dim_date') }}
