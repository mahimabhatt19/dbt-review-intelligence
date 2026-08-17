"""
Loads Amazon Beauty product metadata from HuggingFace into DuckDB.
Reads Parquet files directly (bypasses the deprecated loading script path).
"""
import duckdb
import pandas as pd
from huggingface_hub import HfFileSystem

REPO = "McAuley-Lab/Amazon-Reviews-2023"
SUBFOLDER = "raw_meta_All_Beauty"

print("🔍 Discovering Parquet files in HuggingFace repo...")
fs = HfFileSystem()
all_files = fs.ls(f"datasets/{REPO}/{SUBFOLDER}", detail=False)
parquet_files = [f for f in all_files if f.endswith(".parquet")]
print(f"    Found {len(parquet_files)} parquet file(s)")
for f in parquet_files:
    print(f"      • {f.split('/')[-1]}")

print("\n⬇️  Downloading + loading product metadata...")
# Read each parquet file via the hf:// scheme (huggingface_hub handles auth + caching)
dfs = []
for f in parquet_files:
    # Convert 'datasets/REPO/path/file.parquet' → 'hf://datasets/REPO/path/file.parquet'
    hf_url = f"hf://{f}"
    dfs.append(pd.read_parquet(hf_url))

df = pd.concat(dfs, ignore_index=True)
print(f"✅ Fetched {len(df):,} product records")

# Nested columns → cast to strings so DuckDB doesn't choke
nested_cols = ["features", "description", "images", "videos", "categories", "bought_together"]
for col in nested_cols:
    if col in df.columns:
        df[col] = df[col].astype(str)

# Load into DuckDB
con = duckdb.connect("dev.duckdb")
con.sql("CREATE SCHEMA IF NOT EXISTS raw")
con.sql("DROP TABLE IF EXISTS raw.products")
con.sql("CREATE TABLE raw.products AS SELECT * FROM df")

# Verify
count = con.sql("SELECT COUNT(*) FROM raw.products").fetchone()[0]
print(f"✅ Loaded {count:,} rows into raw.products")

print("\n--- Schema ---")
con.sql("DESCRIBE raw.products").show()

print("\n--- Sample rows ---")
con.sql("""
    SELECT parent_asin, title, main_category, store, average_rating, rating_number, price
    FROM raw.products
    LIMIT 5
""").show()

# Coverage check — how many of our review products have metadata?
overlap = con.sql("""
    SELECT COUNT(DISTINCT r.parent_asin) AS matched_products
    FROM raw.reviews r
    INNER JOIN raw.products p ON r.parent_asin = p.parent_asin
""").fetchone()[0]

reviews_products = con.sql("SELECT COUNT(DISTINCT parent_asin) FROM raw.reviews").fetchone()[0]

print(f"\n--- Coverage ---")
print(f"Distinct products in reviews:     {reviews_products:,}")
print(f"Matched to product metadata:      {overlap:,}")
print(f"Match rate:                       {100 * overlap / reviews_products:.1f}%")

con.close()