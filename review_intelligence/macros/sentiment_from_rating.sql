{#
  Converts a numeric rating column into a categorical sentiment_bucket.
  Reusable across models to keep sentiment logic consistent.

  Args:
    rating_column (str): the SQL column name containing the rating
    positive_threshold (int, default=4): rating >= this is 'positive'
    negative_threshold (int, default=2): rating <= this is 'negative'
  Usage:
    select {{ sentiment_from_rating('rating') }} as sentiment_bucket from ...
#}

{% macro sentiment_from_rating(rating_column, positive_threshold=4, negative_threshold=2) %}
    case
        when {{ rating_column }} >= {{ positive_threshold }} then 'positive'
        when {{ rating_column }} <= {{ negative_threshold }} then 'negative'
        else 'neutral'
    end
{% endmacro %}