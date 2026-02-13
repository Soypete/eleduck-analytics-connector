-- Generic audit to check for positive values
-- Usage: Add to model with audit: assert_positive_values(column=column_name)

AUDIT (
    name assert_positive_values,
    blocking true,
);

SELECT *
FROM @this_model
WHERE @column < 0
