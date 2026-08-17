{{ config(materialized='table') }}

-- Grain: one row per (product_id, month_start_date).
-- Aggregates reviews at monthly granularity per product for time-series analytics.

with reviews as (

    select * from {{ ref('fct_reviews') }}

),

monthly as (

    select
        product_id,
        cast(date_trunc('month', reviewed_date) as date) as month_start_date,

        -- Volume
        count(*)                                              as review_count,
        count(distinct reviewer_id)                           as distinct_reviewer_count,

        -- Ratings
        round(avg(rating), 2)                                 as avg_rating,
        min(rating)                                           as min_rating,
        max(rating)                                           as max_rating,

        -- Sentiment mix
        sum(case when sentiment_bucket = 'positive' then 1 else 0 end) as positive_review_count,
        sum(case when sentiment_bucket = 'neutral'  then 1 else 0 end) as neutral_review_count,
        sum(case when sentiment_bucket = 'negative' then 1 else 0 end) as negative_review_count,

        round(
            100.0 * sum(case when sentiment_bucket = 'negative' then 1 else 0 end) / count(*),
            1
        )                                                     as negative_review_pct,

        -- Trust
        sum(case when is_verified_purchase then 1 else 0 end) as verified_purchase_review_count,
        sum(helpful_vote_count)                               as total_helpful_votes

    from reviews
    group by product_id, cast(date_trunc('month', reviewed_date) as date)

)

select * from monthly