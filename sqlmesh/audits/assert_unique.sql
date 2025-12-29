-- Generic audit to check for unique values
-- Usage: Add to model with audit: assert_unique(column=column_name)

AUDIT (
    name assert_unique,
    blocking true,
);

SELECT @column, COUNT(*) AS cnt
FROM @this_model
GROUP BY @column
HAVING COUNT(*) > 1
