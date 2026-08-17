{{ config(materialized='table') }}

-- Composite "risk score" for products deserving investigation.
-- Combines volume, sentiment, trust, and reviewer-quality signals into one ranked list.
-- Grain: one row per product_id (only products with reviews).

with products as (

    select * from {{ ref('dim_products') }}
    where our_review_count > 0

),

-- Reviewer-context signal: how much do harsh reviewers hate this product?
harsh_reviewer_signal as (

    select
        product_id,
        sum(case when is_high_signal_negative then 1 else 0 end)     as high_signal_negative_count,
        sum(case when is_high_signal_positive then 1 else 0 end)     as high_signal_positive_count
    from {{ ref('int_reviews_with_reviewer_context') }}
    group by product_id

),

-- Recency signal: is the negative sentiment recent or old?
recent_sentiment as (

    select
        product_id,
        round(avg(rating), 2)                                        as avg_rating_last_90d,
        sum(case when sentiment_bucket = 'negative' then 1 else 0 end) as negative_count_last_90d,
        count(*)                                                     as review_count_last_90d
    from {{ ref('fct_reviews') }}
    where reviewed_date >= (
        select max(reviewed_date) - interval 90 day from {{ ref('fct_reviews') }}
    )
    group by product_id

),

joined as (

    select
        p.product_id,
        p.product_title,
        p.brand,
        p.subcategory,
        p.category_group,
        p.is_premium,
        p.price_bucket,

        p.our_review_count,
        p.our_avg_rating,
        p.negative_review_pct,
        p.verified_review_pct,
        p.review_volume_bucket,

        coalesce(hrs.high_signal_negative_count, 0)         as high_signal_negative_count,
        coalesce(hrs.high_signal_positive_count, 0)         as high_signal_positive_count,

        rs.avg_rating_last_90d,
        rs.negative_count_last_90d,
        rs.review_count_last_90d,

        -- Trend delta: recent avg minus overall avg. Negative = getting worse.
        case
            when rs.avg_rating_last_90d is null then null
            else round(rs.avg_rating_last_90d - p.our_avg_rating, 2)
        end                                                  as recent_rating_delta

    from products p
    left join harsh_reviewer_signal hrs on p.product_id = hrs.product_id
    left join recent_sentiment       rs  on p.product_id = rs.product_id

),

scored as (

    select
        *,

        -- Composite risk score (0-100). Higher = more concerning.
        -- Weighted mix of signals, with volume as a multiplier so we don't over-index
        -- on 1-review products.
        least(100,
            round(
                (
                    -- Base: negative review % (max 40 points)
                    least(negative_review_pct * 0.8, 40)

                    -- Bonus: harsh reviewers dislike it (max 20 points)
                    + least(high_signal_negative_count * 5, 20)

                    -- Bonus: trend is worsening (max 20 points)
                    + case
                        when recent_rating_delta is null then 0
                        when recent_rating_delta < -0.5  then 20
                        when recent_rating_delta < 0      then 10
                        else 0
                      end

                    -- Bonus: low verified % = trust concern (max 10 points)
                    + case
                        when verified_review_pct is null       then 0
                        when verified_review_pct < 40           then 10
                        when verified_review_pct < 60           then 5
                        else 0
                      end

                    -- Bonus: premium product with issues (max 10 points)
                    + case when is_premium and negative_review_pct > 20 then 10 else 0 end
                )
                -- Volume damper: 1-review products can't score >50 no matter what
                * case
                    when our_review_count < 5   then 0.3
                    when our_review_count < 20  then 0.7
                    else 1.0
                  end
            , 1)
        ) as risk_score,

        -- Risk tier for easy filtering
        case
            when our_review_count < 5 then 'insufficient_data'
            when negative_review_pct >= 40 and our_review_count >= 20 then 'critical'
            when negative_review_pct >= 25 and our_review_count >= 10 then 'high'
            when negative_review_pct >= 15                             then 'medium'
            else 'low'
        end as risk_tier

    from joined

)

select *
from scored
order by risk_score desc