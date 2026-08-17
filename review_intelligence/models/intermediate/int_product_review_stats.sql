{{ config(materialized='ephemeral') }}

-- Grain: one row per product_id (parent_asin)
-- Computes per-product review aggregations that will be joined into dim_products.

with reviews as (

    select * from {{ ref('fct_reviews') }}

),

per_product as (

    select
        product_id,

        -- Volume
        count(*)                                              as review_count,
        count(distinct reviewer_id)                           as distinct_reviewer_count,

        -- Rating distribution
        round(avg(rating), 2)                                 as avg_rating,
        min(rating)                                           as min_rating,
        max(rating)                                           as max_rating,
        stddev_samp(rating)                                   as rating_stddev,

        -- Star breakdown
        sum(case when rating = 5 then 1 else 0 end)           as five_star_count,
        sum(case when rating = 4 then 1 else 0 end)           as four_star_count,
        sum(case when rating = 3 then 1 else 0 end)           as three_star_count,
        sum(case when rating = 2 then 1 else 0 end)           as two_star_count,
        sum(case when rating = 1 then 1 else 0 end)           as one_star_count,

        -- Sentiment mix (from fct_reviews.sentiment_bucket)
        sum(case when sentiment_bucket = 'positive' then 1 else 0 end) as positive_review_count,
        sum(case when sentiment_bucket = 'neutral'  then 1 else 0 end) as neutral_review_count,
        sum(case when sentiment_bucket = 'negative' then 1 else 0 end) as negative_review_count,

        -- Trust
        sum(case when is_verified_purchase then 1 else 0 end) as verified_purchase_review_count,
        sum(helpful_vote_count)                               as total_helpful_votes,

        -- Time span
        min(reviewed_date)                                    as first_reviewed_date,
        max(reviewed_date)                                    as last_reviewed_date,
        date_diff('day', min(reviewed_date), max(reviewed_date)) as review_span_days

    from reviews
    group by product_id

),

with_pct as (

    select
        *,
        round(100.0 * negative_review_count            / review_count, 1) as negative_review_pct,
        round(100.0 * positive_review_count            / review_count, 1) as positive_review_pct,
        round(100.0 * verified_purchase_review_count   / review_count, 1) as verified_review_pct

    from per_product

)

select * from with_pct