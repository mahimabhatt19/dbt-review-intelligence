{{ config(materialized='table') }}

-- Date dimension covering the full review timespan + one year of forward padding.
-- Powers time-series analytics with easy calendar filters (weekend, quarter, etc.).
-- Grain: one row per date.

with date_range as (

    -- Discover the actual bounds of our review data
    select
        min(reviewed_date) as min_date,
        max(reviewed_date) as max_date
    from {{ ref('fct_reviews') }}

),

spine as (

    {{ dbt_utils.date_spine(
        datepart="day",
        start_date="cast('2000-01-01' as date)",
        end_date="cast('2025-12-31' as date)"
    ) }}

),

filtered as (

    -- Trim spine to our review range + 30-day padding on each side
    select
        cast(date_day as date) as date_day
    from spine
    where date_day >= (select min_date - interval 30 day from date_range)
      and date_day <= (select max_date + interval 30 day from date_range)

),

enriched as (

    select
        date_day                                       as date,

        -- Parts
        year(date_day)                                 as year,
        quarter(date_day)                              as quarter,
        month(date_day)                                as month,
        monthname(date_day)                            as month_name,
        day(date_day)                                  as day_of_month,
        dayofweek(date_day)                            as day_of_week,
        dayname(date_day)                              as day_name,
        weekofyear(date_day)                           as week_of_year,

        -- Convenience flags
        case when dayofweek(date_day) in (0, 6) then true else false end as is_weekend,
        cast(date_trunc('month',   date_day) as date)  as month_start_date,
        cast(date_trunc('quarter', date_day) as date)  as quarter_start_date,
        cast(date_trunc('year',    date_day) as date)  as year_start_date,

        -- Formatted labels for reports
        year(date_day) || '-' || lpad(cast(month(date_day) as varchar), 2, '0')  as year_month,
        'Q' || quarter(date_day) || ' ' || year(date_day)                        as quarter_label

    from filtered

)

select * from enriched