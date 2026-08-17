import duckdb

con = duckdb.connect("dev.duckdb")

print("--- Tables ---")
con.sql("SHOW ALL TABLES").show()

print("\n--- Schema of raw.reviews ---")
con.sql("DESCRIBE raw.reviews").show()

print("\n--- First 3 rows ---")
con.sql("SELECT * FROM raw.reviews LIMIT 3").show()

print("\n--- Row count + distinct products + distinct users ---")
con.sql("""
    SELECT
        COUNT(*) AS total_rows,
        COUNT(DISTINCT asin) AS distinct_products,
        COUNT(DISTINCT user_id) AS distinct_users
    FROM raw.reviews
""").show()

con.close()