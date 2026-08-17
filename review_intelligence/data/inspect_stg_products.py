import duckdb

con = duckdb.connect("dev.duckdb")

print("--- Subcategory distribution ---")
con.sql("""
    SELECT
        subcategory,
        COUNT(*) AS product_count,
        ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct
    FROM main.stg_products
    GROUP BY subcategory
    ORDER BY product_count DESC
""").show()

print("\n--- Category group distribution ---")
con.sql("""
    SELECT category_group, is_premium, COUNT(*) AS product_count
    FROM main.stg_products
    GROUP BY 1, 2
    ORDER BY 3 DESC
""").show()

print("\n--- Price bucket distribution ---")
con.sql("""
    SELECT price_bucket, COUNT(*) AS n
    FROM main.stg_products
    GROUP BY 1
    ORDER BY n DESC
""").show()

print("\n--- Sample products with their derived subcategories ---")
con.sql("""
    SELECT product_id, LEFT(product_title, 60) AS title_preview, subcategory, brand
    FROM main.stg_products
    WHERE subcategory != 'Uncategorized'
    LIMIT 10
""").show()

con.close()