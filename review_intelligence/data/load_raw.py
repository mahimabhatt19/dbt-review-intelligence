"""
Loads Amazon Beauty Reviews from HuggingFace into DuckDB.
Uses the official `datasets` library — handles retries, caching, and mirrors.
"""
import duckdb
from datasets import load_dataset

print("⬇️  Loading Amazon Beauty Reviews from HuggingFace...")
print("    (first run: ~1-2 min to download + cache; later runs: instant)")

# Load the dataset — streams from HuggingFace, caches locally after first run
ds = load_dataset("jhan21/amazon-beauty-reviews-dataset", split="train")

# Sample down to 50K rows — plenty for great analytics, keeps everything snappy
ds_sample = ds.shuffle(seed=42).select(range(50_000))

# Convert to pandas (DuckDB reads pandas DataFrames natively)
df = ds_sample.to_pandas()
print(f"✅ Fetched {len(df):,} rows")

# Drop the 'images' column — it's a nested struct we don't need, and it can trip up DuckDB
if "images" in df.columns:
    df = df.drop(columns=["images"])

# Load into DuckDB
con = duckdb.connect("dev.duckdb")
con.sql("CREATE SCHEMA IF NOT EXISTS raw")
con.sql("DROP TABLE IF EXISTS raw.reviews")
con.sql("CREATE TABLE raw.reviews AS SELECT * FROM df")

# Verify
count = con.sql("SELECT COUNT(*) FROM raw.reviews").fetchone()[0]
print(f"✅ Loaded {count:,} rows into raw.reviews")

print("\n--- Schema ---")
con.sql("DESCRIBE raw.reviews").show()

print("\n--- Sample rows ---")
con.sql("""
    SELECT rating, title, LEFT(text, 60) AS text_preview, verified_purchase
    FROM raw.reviews LIMIT 3
""").show()

con.close()