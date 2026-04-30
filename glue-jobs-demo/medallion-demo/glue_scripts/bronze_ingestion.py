"""
Bronze Layer - Raw Data Ingestion
Generates 1,000 sample e-commerce order records with intentional data quality issues
(mixed date formats, null values, inconsistent casing, ~5% duplicates) and writes
them as JSON to S3 bronze/orders/.
"""
import sys
import random
from datetime import datetime, timedelta
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from pyspark.sql.types import (
    StructType, StructField, StringType, IntegerType, DoubleType
)

args = getResolvedOptions(sys.argv, ["JOB_NAME", "S3_BUCKET"])

sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args["JOB_NAME"], args)

BUCKET = args["S3_BUCKET"]
random.seed(42)

# ── Reference data ────────────────────────────────────────────────────────────

CUSTOMERS = [
    {"id": f"CUST{str(i).zfill(3)}", "name": name,
     "email": f"{name.lower().replace(' ', '.')}@example.com"}
    for i, name in enumerate([
        "Alice Johnson", "Bob Smith", "Carol White", "David Brown", "Eve Davis",
        "Frank Miller", "Grace Wilson", "Henry Moore", "Ivy Taylor", "Jack Anderson",
        "Kate Thomas", "Liam Jackson", "Mia Harris", "Noah Martin", "Olivia Lee",
        "Paul Walker", "Quinn Hall", "Rachel Allen", "Sam Young", "Tina King",
        "Uma Wright", "Victor Scott", "Wendy Green", "Xander Baker", "Yara Nelson",
        "Zach Carter", "Amy Mitchell", "Brian Perez", "Clara Roberts", "Dylan Turner",
    ], 1)
]

PRODUCTS = [
    {"id": "PROD001", "name": "Laptop Pro 15",       "category": "Electronics", "price": 1299.99},
    {"id": "PROD002", "name": "Wireless Headphones",  "category": "Electronics", "price": 199.99},
    {"id": "PROD003", "name": "Smartphone X12",       "category": "Electronics", "price": 899.99},
    {"id": "PROD004", "name": "4K Tablet",            "category": "Electronics", "price": 649.99},
    {"id": "PROD005", "name": "Digital Camera",       "category": "Electronics", "price": 549.99},
    {"id": "PROD006", "name": "Classic Jeans",        "category": "Clothing",    "price": 79.99},
    {"id": "PROD007", "name": "Winter Jacket",        "category": "Clothing",    "price": 149.99},
    {"id": "PROD008", "name": "Running Shoes",        "category": "Clothing",    "price": 119.99},
    {"id": "PROD009", "name": "Smart Watch",          "category": "Clothing",    "price": 299.99},
    {"id": "PROD010", "name": "Cotton T-Shirt",       "category": "Clothing",    "price": 29.99},
    {"id": "PROD011", "name": "Modern Sofa",          "category": "Home",        "price": 899.99},
    {"id": "PROD012", "name": "Floor Lamp",           "category": "Home",        "price": 89.99},
    {"id": "PROD013", "name": "Bookshelf Oak",        "category": "Home",        "price": 199.99},
    {"id": "PROD014", "name": "Area Rug 8x10",        "category": "Home",        "price": 249.99},
    {"id": "PROD015", "name": "Blackout Curtains",    "category": "Home",        "price": 69.99},
    {"id": "PROD016", "name": "Arabica Coffee 1kg",   "category": "Food",        "price": 24.99},
    {"id": "PROD017", "name": "Green Tea Pack",       "category": "Food",        "price": 14.99},
    {"id": "PROD018", "name": "Mixed Nuts 500g",      "category": "Food",        "price": 18.99},
    {"id": "PROD019", "name": "Organic Oats 1kg",     "category": "Food",        "price": 9.99},
    {"id": "PROD020", "name": "Pasta Variety Pack",   "category": "Food",        "price": 12.99},
]

STATUSES         = ["PENDING", "PROCESSING", "SHIPPED", "DELIVERED", "CANCELLED", "RETURNED"]
PAYMENT_METHODS  = ["credit_card", "debit_card", "paypal", "bank_transfer", "gift_card"]
STREETS          = ["Main St", "Oak Ave", "Park Blvd", "Elm Dr", "Maple Ln", "Cedar Rd"]
CITY_STATE_PAIRS = [
    ("New York", "NY"), ("Los Angeles", "CA"), ("Chicago", "IL"),
    ("Houston", "TX"), ("Phoenix", "AZ"), ("Philadelphia", "PA"),
    ("San Antonio", "TX"), ("San Diego", "CA"), ("Dallas", "TX"), ("Austin", "TX"),
]

# ── Record generator ──────────────────────────────────────────────────────────

def random_date():
    base = datetime(2024, 1, 1)
    return base + timedelta(seconds=random.randint(0, 365 * 86400))


def make_record(order_num):
    customer  = random.choice(CUSTOMERS)
    product   = random.choice(PRODUCTS)
    qty       = random.randint(1, 5)
    order_dt  = random_date()
    city, state = random.choice(CITY_STATE_PAIRS)

    # Intentional quality issues ───────────────────────────────────────────────
    # 5%  null customer_name
    cust_name = customer["name"] if random.random() > 0.05 else None

    # 3%  malformed email (missing @)
    email = (customer["email"] if random.random() > 0.03
             else customer["email"].replace("@", ""))

    # 10% category in lowercase instead of Title Case
    category = (product["category"] if random.random() > 0.10
                else product["category"].lower())

    # 5%  date formatted as MM/DD/YYYY instead of ISO
    order_date = (order_dt.strftime("%Y-%m-%d") if random.random() > 0.05
                  else order_dt.strftime("%m/%d/%Y"))

    # Small rounding noise on total_amount
    total = round(qty * product["price"] * (1 + random.uniform(-0.005, 0.005)), 2)

    return {
        "order_id":         f"ORD{str(order_num).zfill(6)}",
        "customer_id":      customer["id"],
        "customer_name":    cust_name,
        "customer_email":   email,
        "product_id":       product["id"],
        "product_name":     product["name"],
        "category":         category,
        "quantity":         qty,
        "unit_price":       product["price"],
        "total_amount":     total,
        "order_date":       order_date,
        "status":           random.choice(STATUSES),
        "shipping_address": f"{random.randint(100, 9999)} {random.choice(STREETS)}, {city}, {state}",
        "payment_method":   random.choice(PAYMENT_METHODS),
        "ingested_at":      datetime.utcnow().isoformat(),
    }


# ── Generate records ──────────────────────────────────────────────────────────

records = [make_record(i) for i in range(1, 1001)]

# Add 5% duplicates to simulate re-ingestion
duplicates = random.sample(records, 50)
records.extend(duplicates)
random.shuffle(records)

print(f"Generated {len(records)} records (1000 base + 50 duplicates)")

# ── Schema ────────────────────────────────────────────────────────────────────

schema = StructType([
    StructField("order_id",         StringType(),  True),
    StructField("customer_id",      StringType(),  True),
    StructField("customer_name",    StringType(),  True),
    StructField("customer_email",   StringType(),  True),
    StructField("product_id",       StringType(),  True),
    StructField("product_name",     StringType(),  True),
    StructField("category",         StringType(),  True),
    StructField("quantity",         IntegerType(), True),
    StructField("unit_price",       DoubleType(),  True),
    StructField("total_amount",     DoubleType(),  True),
    StructField("order_date",       StringType(),  True),
    StructField("status",           StringType(),  True),
    StructField("shipping_address", StringType(),  True),
    StructField("payment_method",   StringType(),  True),
    StructField("ingested_at",      StringType(),  True),
])

# ── Write to S3 bronze ────────────────────────────────────────────────────────

output_path = f"s3://{BUCKET}/bronze/orders/"
df = spark.createDataFrame(records, schema=schema)
df.coalesce(1).write.mode("overwrite").json(output_path)

print(f"Bronze layer: wrote {df.count()} records to {output_path}")

job.commit()
