{{ config(materialized='view') }}

with source as (

    select * from {{ source('amazon_reviews', 'reviews') }}

),

renamed_and_cleaned as (

    select
        -- IDs
        parent_asin                             as product_id,
        asin                                    as variant_id,
        user_id                                 as reviewer_id,

        -- Review content
        title                                   as review_title,
        text                                    as review_text,

        -- Metrics
        cast(rating as integer)                 as rating,
        cast(helpful_vote as integer)           as helpful_vote_count,

        -- Flags
        verified_purchase                       as is_verified_purchase,

        -- Time — convert unix milliseconds to a real timestamp
        cast(timestamp as timestamp)                    as reviewed_at,
        cast(timestamp as date)                         as reviewed_date,


        -- Derived helpers (small + generic; real business logic lives in marts)
        length(text)                                      as review_text_length,
        length(text) - length(replace(text, ' ', '')) + 1 as review_word_count_approx

    from source

    -- Drop obviously bad rows
    where text is not null
      and length(text) > 0
      and asin is not null

)

select * from renamed_and_cleaned