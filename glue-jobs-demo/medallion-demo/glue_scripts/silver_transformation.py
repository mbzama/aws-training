"""
Silver Layer - Cleansed & Conformed Data
Reads raw JSON from bronze/orders/, applies data quality rules, and writes
deduplicated, typed Parquet to silver/orders/.

Quality fixes applied:
  - Deduplicate on order_id (keep first occurrence by ingested_at)
  - Standardise order_date to ISO-8601 (handles MM/DD/YYYY and YYYY-MM-DD)
  - Normalise category to Title Case
  - Recalculate total_amount = quantity * unit_price (removes rounding noise)
  - Flag rows with null customer_name or invalid email; keep them with a flag
  - Add silver metadata columns (processed_at, dq_flags)
"""
import sys
import re
from datetime import datetime
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from pyspark.sql import functions as F
from pyspark.sql.types import StringType, BooleanType
from pyspark.sql.window import Window

args = getResolvedOptions(sys.argv, ["JOB_NAME", "S3_BUCKET"])

sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args["JOB_NAME"], args)

BUCKET = args["S3_BUCKET"]

# ── UDFs ──────────────────────────────────────────────────────────────────────

EMAIL_RE = re.compile(r"^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$")


@F.udf(StringType())
def normalise_date(date_str):
    """Accept YYYY-MM-DD or MM/DD/YYYY; return YYYY-MM-DD, or None if unparseable."""
    if date_str is None:
        return None
    for fmt in ("%Y-%m-%d", "%m/%d/%Y"):
        try:
            return datetime.strptime(date_str, fmt).strftime("%Y-%m-%d")
        except ValueError:
            pass
    return None


@F.udf(BooleanType())
def is_valid_email(email):
    if email is None:
        return False
    return bool(EMAIL_RE.match(email))


# ── Read bronze ───────────────────────────────────────────────────────────────

bronze_path = f"s3://{BUCKET}/bronze/orders/"
raw_df = spark.read.json(bronze_path)

print(f"Bronze records read: {raw_df.count()}")

# ── Deduplicate: keep the earliest ingestion of each order_id ─────────────────

window = Window.partitionBy("order_id").orderBy("ingested_at")
dedup_df = (
    raw_df
    .withColumn("_row_num", F.row_number().over(window))
    .filter(F.col("_row_num") == 1)
    .drop("_row_num")
)

print(f"After deduplication: {dedup_df.count()}")

# ── Transformations ───────────────────────────────────────────────────────────

silver_df = (
    dedup_df
    # Normalise date
    .withColumn("order_date", normalise_date(F.col("order_date")))
    # Title-case category
    .withColumn("category", F.initcap(F.col("category")))
    # Recalculate total to remove rounding noise
    .withColumn("total_amount", F.round(F.col("quantity") * F.col("unit_price"), 2))
    # Fill null customer_name with a placeholder
    .withColumn(
        "customer_name",
        F.coalesce(F.col("customer_name"), F.lit("Unknown"))
    )
    # Data-quality flags (comma-separated list; empty string = clean row)
    .withColumn(
        "dq_flags",
        F.concat_ws(",",
            F.when(F.col("customer_name") == "Unknown", F.lit("null_customer_name"))
             .otherwise(F.lit(None).cast(StringType())),
            F.when(~is_valid_email(F.col("customer_email")), F.lit("invalid_email"))
             .otherwise(F.lit(None).cast(StringType())),
            F.when(F.col("order_date").isNull(), F.lit("unparseable_date"))
             .otherwise(F.lit(None).cast(StringType())),
        )
    )
    # Cast types
    .withColumn("order_date",    F.to_date(F.col("order_date"), "yyyy-MM-dd"))
    .withColumn("quantity",      F.col("quantity").cast("integer"))
    .withColumn("unit_price",    F.col("unit_price").cast("double"))
    .withColumn("total_amount",  F.col("total_amount").cast("double"))
    # Silver metadata
    .withColumn("processed_at",  F.lit(datetime.utcnow().isoformat()))
)

# ── Write to S3 silver ────────────────────────────────────────────────────────

silver_path = f"s3://{BUCKET}/silver/orders/"
(
    silver_df
    .coalesce(2)
    .write
    .mode("overwrite")
    .partitionBy("category")
    .parquet(silver_path)
)

total    = silver_df.count()
flagged  = silver_df.filter(F.col("dq_flags") != "").count()
print(f"Silver layer: wrote {total} records ({flagged} with DQ flags) to {silver_path}")
print("Category distribution:")
silver_df.groupBy("category").count().orderBy("category").show()

job.commit()
