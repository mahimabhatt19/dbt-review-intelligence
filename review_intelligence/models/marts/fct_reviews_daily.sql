{{ config(materialized='table') }}

with reviews as (

    select * from {{ ref('fct_reviews') }}

),

daily as (

    select
        reviewed_date,

        count(*)                                              as reviews_count,
        count(distinct product_id)                            as products_reviewed,
        count(distinct reviewer_id)                           as distinct_reviewers,

        round(avg(rating), 2)                                 as avg_rating,

        sum(case when sentiment_bucket = 'positive' then 1 else 0 end) as positive_reviews,
        sum(case when sentiment_bucket = 'neutral'  then 1 else 0 end) as neutral_reviews,
        sum(case when sentiment_bucket = 'negative' then 1 else 0 end) as negative_reviews,

        round(100.0 * sum(case when sentiment_bucket = 'negative' then 1 else 0 end) / count(*), 1) as negative_review_pct

    from reviews
    group by reviewed_date

)

select * from daily
order by reviewed_date