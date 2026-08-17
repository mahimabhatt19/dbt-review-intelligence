import duckdb

con = duckdb.connect("dev.duckdb")

print("--- All main_category values in raw.products ---")
con.sql("""
    SELECT
        main_category,
        COUNT(*) AS products
    FROM raw.products
    GROUP BY main_category
    ORDER BY products DESC
""").show()

print("\n--- main_category values for products actually in our reviews ---")
con.sql("""
    SELECT
        p.main_category,
        COUNT(DISTINCT p.parent_asin) AS products,
        COUNT(*) AS review_count
    FROM raw.products p
    INNER JOIN raw.reviews r ON r.parent_asin = p.parent_asin
    GROUP BY p.main_category
    ORDER BY review_count DESC
""").show()

con.close()