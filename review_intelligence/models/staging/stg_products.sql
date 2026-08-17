{{ config(materialized='view') }}

-- Staging: cleaned Amazon Beauty product metadata.
-- Combines real source fields with derived enrichments:
--   1. Normalizes main_category via the main_category_mapping seed
--   2. Derives subcategory from title keywords via the subcategory_rules seed
-- Grain: one row per parent_asin (product).

with source as (

    select * from {{ source('amazon_reviews', 'products') }}

),

deduped as (

    -- Some products appear twice in the source. Keep the row with the most reviews.
    select *
    from (
        select
            *,
            row_number() over (
                partition by parent_asin
                order by rating_number desc nulls last
            ) as row_num
        from source
    )
    where row_num = 1

),

cleaned as (

    select
        parent_asin                                 as product_id,
        title                                       as product_title,
        main_category,
        store                                       as brand,

        -- Rating fields directly from Amazon
        cast(average_rating as double)              as amazon_average_rating,
        cast(rating_number as integer)              as amazon_rating_count,

        -- Price is stored as string 'None' or a number-string — normalize it
        case
            when price is null or price = 'None' or price = '' then null
            else try_cast(price as double)
        end                                         as price_usd,

        -- Lowercase title for keyword matching
        lower(title)                                as title_lower

    from deduped
    where parent_asin is not null

),

-- Enrichment 1: normalize main_category via seed
with_category_group as (

    select
        c.*,
        coalesce(m.category_group, 'Unknown')       as category_group,
        coalesce(m.is_premium, false)               as is_premium

    from cleaned c
    left join {{ ref('main_category_mapping') }} m
        on c.main_category = m.main_category

),

-- Enrichment 2: derive subcategory from title keywords via seed
-- For each product, pick the highest-priority matching rule.
subcategory_matches as (

    select
        p.product_id,
        r.subcategory,
        r.priority,
        row_number() over (
            partition by p.product_id
            order by r.priority desc, r.subcategory  -- tiebreak alphabetically
        ) as match_rank
    from with_category_group p
    inner join {{ ref('subcategory_rules') }} r
        on regexp_matches(p.title_lower, r.keyword_pattern)

),

best_subcategory as (

    select
        product_id,
        subcategory as derived_subcategory
    from subcategory_matches
    where match_rank = 1

),

final as (

    select
        p.product_id,
        p.product_title,
        p.brand,
        p.main_category,
        p.category_group,
        p.is_premium,
        coalesce(s.derived_subcategory, 'Uncategorized') as subcategory,
        p.amazon_average_rating,
        p.amazon_rating_count,
        p.price_usd,

        -- Price bucket — for products where we have prices
        case
            when p.price_usd is null then 'unknown'
            when p.price_usd < 10  then 'under_10'
            when p.price_usd < 25  then '10_to_25'
            when p.price_usd < 50  then '25_to_50'
            when p.price_usd < 100 then '50_to_100'
            else 'over_100'
        end                                          as price_bucket,

        -- Data quality flag
        case
            when p.amazon_rating_count is null or p.amazon_rating_count = 0
                then true
            else false
        end                                          as is_new_or_unreviewed

    from with_category_group p
    left join best_subcategory s on p.product_id = s.product_id

)

select * from final