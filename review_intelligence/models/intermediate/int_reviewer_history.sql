{{ config(materialized='ephemeral') }}

-- Grain: one row per reviewer_id
-- Computes lifetime aggregates + harshness score.

with reviews as (

    select * from {{ ref('stg_reviews') }}

),

global_stats as (

    -- Single-row CTE: the global average rating across all reviews.
    -- Used to compute per-reviewer harshness.
    select
        avg(rating) as global_avg_rating
    from reviews

),

per_reviewer as (

    select
        reviewer_id,

        -- Activity
        count(*)                                as lifetime_review_count,
        min(reviewed_date)                      as first_reviewed_date,
        max(reviewed_date)                      as last_reviewed_date,
        date_diff('day', min(reviewed_date), max(reviewed_date)) as active_days_span,

        -- Rating behavior
        round(avg(rating), 3)                   as avg_rating_given,
        stddev_samp(rating)                     as rating_stddev,

        -- Verified-purchase behavior
        sum(case when is_verified_purchase then 1 else 0 end) as verified_review_count,
        round(100.0 * sum(case when is_verified_purchase then 1 else 0 end) / count(*), 1) as verified_review_pct,

        -- Text engagement
        round(avg(review_text_length), 0)       as avg_review_text_length,
        sum(helpful_vote_count)                 as total_helpful_votes_received,

        -- Product diversity
        count(distinct product_id)              as distinct_products_reviewed

    from reviews
    group by reviewer_id

),

with_harshness as (

    select
        p.*,
        g.global_avg_rating,

        -- Harshness score: (reviewer's avg) - (global avg).
        -- Negative = harsher than average, positive = more generous.
        round(p.avg_rating_given - g.global_avg_rating, 3) as harshness_score,

        -- Categorical harshness bucket for easier filtering downstream
        case
            when p.lifetime_review_count < 3 then 'insufficient_data'
            when (p.avg_rating_given - g.global_avg_rating) < -0.75 then 'harsh'
            when (p.avg_rating_given - g.global_avg_rating) > 0.75 then 'generous'
            else 'balanced'
        end as reviewer_tendency,

        -- Prolific flag — 5+ reviews
        case when p.lifetime_review_count >= 5 then true else false end as is_prolific_reviewer

    from per_reviewer p
    cross join global_stats g

)

select * from with_harshness