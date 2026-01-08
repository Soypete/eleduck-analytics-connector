{% macro parse_youtube_duration(duration_column) %}
{#
    Parses YouTube ISO 8601 duration format (PT#H#M#S) to seconds.
    Examples:
      - PT1H30M15S -> 5415 seconds
      - PT30M -> 1800 seconds
      - PT45S -> 45 seconds
#}
    coalesce(
        (
            -- Extract hours
            coalesce(
                (regexp_match({{ duration_column }}, 'PT(\d+)H'))[1]::int * 3600,
                0
            ) +
            -- Extract minutes
            coalesce(
                (regexp_match({{ duration_column }}, '(\d+)M'))[1]::int * 60,
                0
            ) +
            -- Extract seconds
            coalesce(
                (regexp_match({{ duration_column }}, '(\d+)S'))[1]::int,
                0
            )
        ),
        0
    )
{% endmacro %}
