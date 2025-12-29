-- Audit to ensure date_key values exist in dim_date
-- Usage: Add to model with audit: assert_valid_date_key(column=date_key_column)

AUDIT (
    name assert_valid_date_key,
    blocking true,
);

SELECT f.@column
FROM @this_model f
LEFT JOIN analytics.dim_date d ON f.@column = d.date_key
WHERE d.date_key IS NULL AND f.@column IS NOT NULL
