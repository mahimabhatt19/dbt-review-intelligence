{#
  Snapshot: tracks changes to product metadata over time.
  Every time a product's title, brand, category_group, price_bucket,
  or amazon_average_rating changes, dbt logs the old + new versions
  with valid-from / valid-to timestamps (SCD Type 2 pattern).

  Not populated automatically — run `dbt snapshot` to capture a version.
#}

{% snapshot snap_products %}

    {{
        config(
          target_schema='snapshots',
          strategy='check',
          unique_key='product_id',
          check_cols=['product_title', 'brand', 'category_group', 'subcategory', 'price_bucket', 'amazon_average_rating']
        )
    }}

    select * from {{ ref('stg_products') }}

{% endsnapshot %}