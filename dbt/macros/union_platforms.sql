{% macro union_platform_content(platform_models) %}
    {% for model in platform_models %}
        select * from {{ ref(model) }}
        {% if not loop.last %}union all{% endif %}
    {% endfor %}
{% endmacro %}
