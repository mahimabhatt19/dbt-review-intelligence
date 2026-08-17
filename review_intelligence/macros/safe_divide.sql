{#
  Safely divide numerator by denominator.
  Returns NULL (not division-by-zero error) when denominator is 0 or NULL.

  Args:
    numerator (str): SQL expression for the numerator
    denominator (str): SQL expression for the denominator
    default_value (str, optional): value to return when denominator is 0/null (default: NULL)
  Usage:
    {{ safe_divide('negative_reviews', 'total_reviews') }}          → returns NULL if total=0
    {{ safe_divide('negative_reviews', 'total_reviews', '0') }}     → returns 0 if total=0
#}

{% macro safe_divide(numerator, denominator, default_value='null') %}
    case
        when {{ denominator }} = 0 or {{ denominator }} is null then {{ default_value }}
        else ({{ numerator }})::double / ({{ denominator }})::double
    end
{% endmacro %}