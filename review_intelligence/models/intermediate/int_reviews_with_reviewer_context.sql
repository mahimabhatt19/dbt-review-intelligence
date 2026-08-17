{{ config(materialized='ephemeral') }}

-- Grain: one row per review.
-- Adds reviewer-level context (harshness, tendency, prolific flag) to each review.
-- Enables analytics like: "products loved by harsh reviewers" (strong signal).

with reviews as (

    select * from {{ ref('fct_reviews') }}

),

reviewer_context as (

    select
        reviewer_id,
        lifetime_review_count,
        harshness_score,
        reviewer_tendency,
        is_prolific_reviewer

    from {{ ref('int_reviewer_history') }}

),

joined as (

    select
        r.*,
        rc.lifetime_review_count                   as reviewer_lifetime_review_count,
        rc.harshness_score                         as reviewer_harshness_score,
        rc.reviewer_tendency,
        rc.is_prolific_reviewer,

        -- The killer flag — a 5-star review from a harsh reviewer is real signal.
        case
            when r.rating >= 4 and rc.reviewer_tendency = 'harsh'
                then true
            else false
        end as is_high_signal_positive,

        -- Inverse — a 1-star from a generous reviewer is a real red flag
        case
            when r.rating <= 2 and rc.reviewer_tendency = 'generous'
                then true
            else false
        end as is_high_signal_negative

    from reviews r
    left join reviewer_context rc on r.reviewer_id = rc.reviewer_id

)

select * from joined