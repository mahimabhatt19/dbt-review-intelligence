{{ config(materialized='table') }}

-- Reviewer-level dimension.
-- Wraps int_reviewer_history with analytical buckets and flags.
-- Grain: one row per reviewer_id.

with reviewers as (

    select * from {{ ref('int_reviewer_history') }}

),

enriched as (

    select
        reviewer_id,

        -- Activity
        lifetime_review_count,
        distinct_products_reviewed,
        first_reviewed_date,
        last_reviewed_date,
        active_days_span,

        -- Rating behavior
        avg_rating_given,
        rating_stddev,
        harshness_score,
        reviewer_tendency,

        -- Trust
        verified_review_count,
        verified_review_pct,

        -- Text engagement
        avg_review_text_length,
        total_helpful_votes_received,

        -- Flags
        is_prolific_reviewer,

        -- Derived engagement bucket
        case
            when lifetime_review_count = 1               then 'one_shot'
            when lifetime_review_count between 2 and 4   then 'occasional'
            when lifetime_review_count between 5 and 20  then 'regular'
            else 'power_reviewer'
        end                                              as engagement_bucket,

        -- Consistency bucket (low stddev = consistent ratings across products)
        case
            when rating_stddev is null                   then 'insufficient_data'
            when rating_stddev < 0.5                     then 'very_consistent'
            when rating_stddev < 1.0                     then 'consistent'
            when rating_stddev < 1.5                     then 'variable'
            else 'highly_variable'
        end                                              as rating_consistency,

        -- "Trusted reviewer" flag — prolific + not one-star-bomber + not fanboy
        case
            when is_prolific_reviewer
                 and reviewer_tendency = 'balanced'
                 and verified_review_pct > 50
                then true
            else false
        end                                              as is_trusted_reviewer

    from reviewers

)

select * from enriched