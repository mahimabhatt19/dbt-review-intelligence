{#
  Generic test: asserts a column contains only values >= 0.
  Fails on negative values; nulls are allowed by default.

  Usage in schema.yml:
    columns:
      - name: review_count
        data_tests:
          - positive_or_zero
#}

{% test positive_or_zero(model, column_name) %}

    select *
    from {{ model }}
    where {{ column_name }} < 0

{% endtest %}