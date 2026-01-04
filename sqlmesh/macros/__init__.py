"""SQLMesh macros for eleduck_analytics project."""

from sqlmesh import macro
from sqlmesh.core.macros import MacroEvaluator


@macro()
def generate_surrogate_key(evaluator: MacroEvaluator, *fields) -> str:
    """
    Generate a surrogate key from one or more fields using MD5 hash.

    Args:
        *fields: Fields to include in the surrogate key

    Returns:
        SQL expression for surrogate key
    """
    # Convert fields to SQL expressions
    field_list = []
    for field in fields:
        field_list.append(f"COALESCE(CAST({field} AS TEXT), '')")

    concat_expr = " || '-' || ".join(field_list)
    return f"MD5({concat_expr})"


@macro()
def cents_to_dollars(evaluator: MacroEvaluator, column_name: str) -> str:
    """
    Convert cents to dollars.

    Args:
        column_name: Column containing amount in cents

    Returns:
        SQL expression for amount in dollars
    """
    return f"({column_name}::DECIMAL / 100.0)"


@macro()
def safe_divide(
    evaluator: MacroEvaluator,
    numerator: str,
    denominator: str,
    default: str = "0"
) -> str:
    """
    Safely divide two values, returning default if denominator is zero or null.

    Args:
        numerator: Numerator expression
        denominator: Denominator expression
        default: Default value if division not possible

    Returns:
        SQL CASE expression for safe division
    """
    return f"""CASE
        WHEN {denominator} = 0 OR {denominator} IS NULL THEN {default}
        ELSE {numerator}::DECIMAL / {denominator}::DECIMAL
    END"""


@macro()
def source(evaluator: MacroEvaluator, source_name: str, table_name: str) -> str:
    """
    Reference a source table in the raw schema.

    Args:
        source_name: Source system name (e.g., 'youtube', 'github')
        table_name: Table name within the source

    Returns:
        Fully qualified table reference
    """
    return f"raw.{table_name}"
