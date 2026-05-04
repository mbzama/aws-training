"""
Gold Layer - Business-Ready Aggregations
Reads cleaned Parquet from silver/orders/ and produces four analytical tables:

  gold/daily_sales/        - Revenue, order count, and AOV per day
  gold/customer_summary/   - Lifetime value, order count, and AOV per customer
  gold/product_performance/ - Units sold, revenue, and avg price per product
  gold/category_metrics/   - Revenue, order count, and share-of-revenue per category
"""
import sys
import socket
from datetime import datetime
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from pyspark.sql import functions as F

args = getResolvedOptions(sys.argv, ["JOB_NAME", "S3_BUCKET"])

sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args["JOB_NAME"], args)


def log_network_info(sc, job_name):
    import time
    driver_ip = socket.gethostbyname(socket.gethostname())
    slots = sc.defaultParallelism

    def probe(_):
        time.sleep(1)
        return [socket.gethostbyname(socket.gethostname())]

    executor_ips = sorted(set(
        sc.range(slots, numSlices=slots)
          .mapPartitions(probe)
          .collect()
    ))
    all_ips = sorted(set([driver_ip] + executor_ips))
    subnets = sorted(set(".".join(ip.split(".")[:3]) + ".0/28" for ip in all_ips))
    print(f"[NETWORK] job={job_name} driver_ip={driver_ip}")
    print(f"[NETWORK] executor_ips={executor_ips}")
    print(f"[NETWORK] all_ips={all_ips}")
    print(f"[NETWORK] subnets_in_use={subnets}")


log_network_info(sc, args["JOB_NAME"])

BUCKET = args["S3_BUCKET"]

# ── Read silver ───────────────────────────────────────────────────────────────

silver_path = f"s3://{BUCKET}/silver/orders/"
df = spark.read.parquet(silver_path)

# Only include successfully fulfilled orders in business metrics
fulfilled_df = df.filter(F.col("status").isin("SHIPPED", "DELIVERED"))

print(f"Silver records: {df.count()}, fulfilled orders: {fulfilled_df.count()}")

processed_at = datetime.utcnow().isoformat()


def add_meta(frame):
    return frame.withColumn("aggregated_at", F.lit(processed_at))


# ── 1. Daily sales summary ────────────────────────────────────────────────────

daily_sales = (
    fulfilled_df
    .groupBy("order_date")
    .agg(
        F.count("order_id")                 .alias("order_count"),
        F.sum("total_amount")               .alias("total_revenue"),
        F.round(F.avg("total_amount"), 2)   .alias("avg_order_value"),
        F.sum("quantity")                   .alias("total_units_sold"),
        F.countDistinct("customer_id")      .alias("unique_customers"),
    )
    .orderBy("order_date")
)

daily_path = f"s3://{BUCKET}/gold/daily_sales/"
add_meta(daily_sales).coalesce(1).write.mode("overwrite").parquet(daily_path)
print(f"daily_sales: {daily_sales.count()} rows written to {daily_path}")


# ── 2. Customer lifetime value summary ───────────────────────────────────────

customer_summary = (
    fulfilled_df
    .groupBy("customer_id", "customer_name")
    .agg(
        F.count("order_id")                 .alias("total_orders"),
        F.sum("total_amount")               .alias("lifetime_value"),
        F.round(F.avg("total_amount"), 2)   .alias("avg_order_value"),
        F.sum("quantity")                   .alias("total_units_bought"),
        F.min("order_date")                 .alias("first_order_date"),
        F.max("order_date")                 .alias("last_order_date"),
        F.collect_set("category")           .alias("purchased_categories"),
    )
    .withColumn("customer_tier",
        F.when(F.col("lifetime_value") >= 3000, F.lit("Platinum"))
         .when(F.col("lifetime_value") >= 1500, F.lit("Gold"))
         .when(F.col("lifetime_value") >= 500,  F.lit("Silver"))
         .otherwise(F.lit("Bronze"))
    )
    .orderBy(F.col("lifetime_value").desc())
)

customer_path = f"s3://{BUCKET}/gold/customer_summary/"
add_meta(customer_summary).coalesce(1).write.mode("overwrite").parquet(customer_path)
print(f"customer_summary: {customer_summary.count()} rows written to {customer_path}")


# ── 3. Product performance ────────────────────────────────────────────────────

product_performance = (
    fulfilled_df
    .groupBy("product_id", "product_name", "category")
    .agg(
        F.sum("quantity")                   .alias("units_sold"),
        F.sum("total_amount")               .alias("total_revenue"),
        F.round(F.avg("unit_price"), 2)     .alias("avg_unit_price"),
        F.count("order_id")                 .alias("order_count"),
        F.countDistinct("customer_id")      .alias("unique_buyers"),
    )
    .orderBy(F.col("total_revenue").desc())
)

product_path = f"s3://{BUCKET}/gold/product_performance/"
add_meta(product_performance).coalesce(1).write.mode("overwrite").parquet(product_path)
print(f"product_performance: {product_performance.count()} rows written to {product_path}")


# ── 4. Category metrics ───────────────────────────────────────────────────────

total_revenue = fulfilled_df.agg(F.sum("total_amount")).collect()[0][0] or 1.0

category_metrics = (
    fulfilled_df
    .groupBy("category")
    .agg(
        F.count("order_id")                 .alias("order_count"),
        F.sum("total_amount")               .alias("category_revenue"),
        F.round(F.avg("total_amount"), 2)   .alias("avg_order_value"),
        F.sum("quantity")                   .alias("units_sold"),
        F.countDistinct("product_id")       .alias("distinct_products"),
        F.countDistinct("customer_id")      .alias("distinct_customers"),
    )
    .withColumn(
        "revenue_share_pct",
        F.round((F.col("category_revenue") / F.lit(total_revenue)) * 100, 2)
    )
    .orderBy(F.col("category_revenue").desc())
)

category_path = f"s3://{BUCKET}/gold/category_metrics/"
add_meta(category_metrics).coalesce(1).write.mode("overwrite").parquet(category_path)
print(f"category_metrics: {category_metrics.count()} rows written to {category_path}")

# ── Summary ───────────────────────────────────────────────────────────────────

print("\n=== Gold Layer Summary ===")
print("Category metrics:")
category_metrics.show(truncate=False)
print("Top 5 customers by lifetime value:")
customer_summary.select("customer_id", "customer_name", "lifetime_value", "customer_tier").show(5)
print("Top 5 products by revenue:")
product_performance.select("product_name", "category", "units_sold", "total_revenue").show(5)

job.commit()
