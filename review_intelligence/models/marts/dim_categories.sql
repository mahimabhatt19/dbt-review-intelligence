{{ config(materialized='table') }}

-- Category dimension.
-- Grain: one row per (category_group, subcategory).
-- Aggregates product counts and review-level performance.

with products as (

    select * from {{ ref('dim_products') }}

),

by_category as (

    select
        category_group,
        subcategory,

        -- Product volume
        count(*)                                      as product_count,
        sum(case when is_premium then 1 else 0 end)   as premium_product_count,

        -- Review volume across products in this category
        sum(our_review_count)                         as total_reviews,
        sum(distinct_reviewer_count)                  as total_distinct_reviewers,

        -- Weighted average of product avg ratings (product-level, not review-level)
        round(avg(our_avg_rating), 3)                 as avg_product_rating,

        -- Sentiment mix
        sum(positive_review_count)                    as positive_review_count,
        sum(negative_review_count)                    as negative_review_count,
        sum(neutral_review_count)                     as neutral_review_count,

        -- Category-level negative %
        round(
            100.0 * sum(negative_review_count) / nullif(sum(our_review_count), 0),
            1
        )                                             as negative_review_pct,

        -- Recency
        min(first_reviewed_date)                      as first_reviewed_date_in_category,
        max(last_reviewed_date)                       as last_reviewed_date_in_category

    from products
    where our_review_count > 0  -- exclude products with no reviews from category health
    group by category_group, subcategory

)

select * from by_category