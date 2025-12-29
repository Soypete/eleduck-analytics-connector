-- Generic audit to check for non-null values
-- Usage: Add to model with audit: assert_not_null(column=column_name)

AUDIT (
    name assert_not_null,
    blocking true,
);

SELECT *
FROM @this_model
WHERE @column IS NULL
