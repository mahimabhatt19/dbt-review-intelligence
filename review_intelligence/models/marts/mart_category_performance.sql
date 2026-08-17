{{ config(materialized='table') }}

-- Category performance scorecard.
-- Grain: one row per subcategory.
-- Segments performance by reviewer_tendency to expose sentiment differences
-- between harsh and generous reviewers.

with reviews_with_context as (

    select * from {{ ref('int_reviews_with_reviewer_context') }}

),

products as (

    select product_id, subcategory, category_group from {{ ref('dim_products') }}

),

joined as (

    select
        p.category_group,
        p.subcategory,
        r.rating,
        r.sentiment_bucket,
        r.reviewer_tendency,
        r.is_verified_purchase

    from reviews_with_context r
    inner join products p on r.product_id = p.product_id

),

per_subcategory as (

    select
        category_group,
        subcategory,

        count(*)                                              as total_reviews,
        round(avg(rating), 2)                                 as overall_avg_rating,

        -- Harsh reviewers' view — the tough crowd
        round(avg(case when reviewer_tendency = 'harsh' then rating end), 2)     as harsh_reviewer_avg_rating,
        count(case when reviewer_tendency = 'harsh' then 1 end)                  as harsh_reviewer_count,

        -- Generous reviewers' view — the easy crowd
        round(avg(case when reviewer_tendency = 'generous' then rating end), 2)  as generous_reviewer_avg_rating,
        count(case when reviewer_tendency = 'generous' then 1 end)               as generous_reviewer_count,

        -- Balanced reviewers — the middle
        round(avg(case when reviewer_tendency = 'balanced' then rating end), 2)  as balanced_reviewer_avg_rating,
        count(case when reviewer_tendency = 'balanced' then 1 end)               as balanced_reviewer_count,

        -- Negative rate
        round(
            100.0 * sum(case when sentiment_bucket = 'negative' then 1 else 0 end) / count(*),
            1
        )                                                     as negative_review_pct,

        -- Verified trust
        round(
            100.0 * sum(case when is_verified_purchase then 1 else 0 end) / count(*),
            1
        )                                                     as verified_review_pct

    from joined
    group by category_group, subcategory

),

with_signals as (

    select
        *,

        -- The key insight signal: gap between harsh and generous reviewer avg.
        -- Large gap = polarizing category (love-it-or-hate-it products).
        case
            when harsh_reviewer_avg_rating is null or generous_reviewer_avg_rating is null then null
            else round(generous_reviewer_avg_rating - harsh_reviewer_avg_rating, 2)
        end as polarization_score,

        -- Category health: overall avg + rate. Buckets for easy filtering.
        case
            when overall_avg_rating >= 4.3 and negative_review_pct < 15  then 'healthy'
            when overall_avg_rating >= 3.8 and negative_review_pct < 25  then 'stable'
            when overall_avg_rating >= 3.3                                then 'watch'
            else 'struggling'
        end as category_health

    from per_subcategory

)

select *
from with_signals
order by total_reviews desc