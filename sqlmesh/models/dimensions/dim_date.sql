MODEL (
    name analytics.dim_date,
    kind FULL,
    cron '@daily',
    grain date_key,
    description 'Date dimension with calendar and fiscal attributes'
);

SELECT
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
    is_weekend::BOOLEAN AS is_weekend,
    fiscal_year,
    fiscal_quarter,

    -- Calculated fields
    year || '-Q' || quarter AS year_quarter,
    year || '-' || LPAD(month::TEXT, 2, '0') AS year_month,
    fiscal_year || '-FQ' || fiscal_quarter AS fiscal_year_quarter

FROM analytics.seed_dim_date
