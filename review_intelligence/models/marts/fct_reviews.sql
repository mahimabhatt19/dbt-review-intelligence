{{ config(materialized='table') }}

with reviews as (

    select * from {{ ref('stg_reviews') }}

),

deduped as (

    -- Some reviewers submit duplicate reviews at the same second
    -- (Amazon system glitch, submit-twice, or variants under the same parent ASIN).
    -- We keep the row with the longest review text — likely the most complete version.
    select *
    from (
        select
            *,
            row_number() over (
                partition by reviewer_id, product_id, reviewed_at
                order by review_text_length desc, helpful_vote_count desc
            ) as row_num
        from reviews
    )
    where row_num = 1

),

enriched as (

    select
        {{ dbt_utils.generate_surrogate_key(['reviewer_id', 'product_id', 'reviewed_at']) }} as review_key,

        product_id,
        variant_id,
        reviewer_id,

        review_title,
        review_text,
        review_text_length,
        review_word_count_approx,

        rating,
        helpful_vote_count,
        is_verified_purchase,

        reviewed_at,
        reviewed_date,

        -- Refactored: uses reusable macro instead of inline CASE
        {{ sentiment_from_rating('rating') }} as sentiment_bucket,

        case
            when review_text_length < 50 then 'short'
            when review_text_length < 300 then 'medium'
            else 'long'
        end as review_length_bucket,

        case
            when helpful_vote_count = 0 then false
            else true
        end as has_helpful_votes

    from deduped

)

select * from enriched