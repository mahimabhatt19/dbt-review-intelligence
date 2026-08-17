{{ config(materialized='table') }}

-- Product-level dimension.
-- Combines product metadata (from stg_products) with review aggregations
-- (from int_product_review_stats).
-- Grain: one row per product_id.

with products as (

    select * from {{ ref('stg_products') }}

),

review_stats as (

    select * from {{ ref('int_product_review_stats') }}

),

joined as (

    select
        -- ── Identifiers ───────────────────────────────
        p.product_id,

        -- ── Metadata (from stg_products) ──────────────
        p.product_title,
        p.brand,
        p.main_category,
        p.category_group,
        p.subcategory,
        p.is_premium,
        p.price_usd,
        p.price_bucket,
        p.amazon_average_rating,
        p.amazon_rating_count,

        -- ── Our review-based metrics (from int_product_review_stats) ──
        coalesce(rs.review_count, 0)                as our_review_count,
        coalesce(rs.distinct_reviewer_count, 0)     as distinct_reviewer_count,
        rs.avg_rating                                as our_avg_rating,
        rs.rating_stddev,

        rs.five_star_count,
        rs.four_star_count,
        rs.three_star_count,
        rs.two_star_count,
        rs.one_star_count,

        rs.positive_review_count,
        rs.neutral_review_count,
        rs.negative_review_count,

        rs.negative_review_pct,
        rs.positive_review_pct,
        rs.verified_review_pct,

        rs.total_helpful_votes,
        rs.first_reviewed_date,
        rs.last_reviewed_date,
        rs.review_span_days,

        -- ── Derived analytical flags ──────────────────
        case
            when rs.review_count is null then 'no_reviews'
            when rs.review_count < 5     then 'sparse'
            when rs.review_count < 20    then 'moderate'
            else 'well_reviewed'
        end                                          as review_volume_bucket,

        -- Divergence between Amazon's public rating and ours (sample bias check)
        case
            when p.amazon_average_rating is null or rs.avg_rating is null then null
            else round(rs.avg_rating - p.amazon_average_rating, 2)
        end                                          as our_vs_amazon_rating_delta,

        -- Recency flag — reviewed in last 12 months of our data window
        case
            when rs.last_reviewed_date is null then false
            when date_diff(
                'day',
                rs.last_reviewed_date,
                (select max(last_reviewed_date) from review_stats)
            ) <= 365 then true
            else false
        end                                          as is_recently_reviewed

    from products p
    left join review_stats rs on p.product_id = rs.product_id

)

select * from joined