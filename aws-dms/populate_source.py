#!/usr/bin/env python3
"""
Populate source RDS (PostgreSQL) with a 'customers' table containing 5,000 records.

Usage:
  pip install psycopg2-binary
  python populate_source.py --host <source_rds_endpoint> --password <db_password>
"""

import argparse
import random
import psycopg2
from datetime import datetime, timedelta

FIRST_NAMES = [
    "James", "Mary", "John", "Patricia", "Robert", "Jennifer", "Michael", "Linda",
    "William", "Barbara", "David", "Elizabeth", "Richard", "Susan", "Joseph", "Jessica",
    "Thomas", "Sarah", "Charles", "Karen", "Christopher", "Lisa", "Daniel", "Nancy",
    "Matthew", "Betty", "Anthony", "Margaret", "Mark", "Sandra", "Donald", "Ashley",
    "Steven", "Dorothy", "Paul", "Kimberly", "Andrew", "Emily", "Joshua", "Donna",
]

LAST_NAMES = [
    "Smith", "Johnson", "Williams", "Brown", "Jones", "Garcia", "Miller", "Davis",
    "Rodriguez", "Martinez", "Hernandez", "Lopez", "Gonzalez", "Wilson", "Anderson",
    "Thomas", "Taylor", "Moore", "Jackson", "Martin", "Lee", "Perez", "Thompson",
    "White", "Harris", "Sanchez", "Clark", "Ramirez", "Lewis", "Robinson", "Walker",
    "Young", "Allen", "King", "Wright", "Scott", "Torres", "Nguyen", "Hill", "Flores",
]

CITIES_STATES = [
    ("New York", "NY"), ("Los Angeles", "CA"), ("Chicago", "IL"), ("Houston", "TX"),
    ("Phoenix", "AZ"), ("Philadelphia", "PA"), ("San Antonio", "TX"), ("San Diego", "CA"),
    ("Dallas", "TX"), ("San Jose", "CA"), ("Austin", "TX"), ("Jacksonville", "FL"),
    ("Fort Worth", "TX"), ("Columbus", "OH"), ("Charlotte", "NC"), ("Indianapolis", "IN"),
    ("San Francisco", "CA"), ("Seattle", "WA"), ("Denver", "CO"), ("Nashville", "TN"),
]

DOMAINS = ["gmail.com", "yahoo.com", "hotmail.com", "outlook.com", "icloud.com"]

PRODUCTS = [
    "Laptop", "Smartphone", "Tablet", "Headphones", "Monitor", "Keyboard",
    "Mouse", "Webcam", "Speaker", "Charger", "USB Hub", "SSD Drive",
]

STATUSES = ["active", "inactive", "pending", "suspended"]


def random_date(start_year=2020, end_year=2025):
    start = datetime(start_year, 1, 1)
    end = datetime(end_year, 12, 31)
    delta = end - start
    return start + timedelta(days=random.randint(0, delta.days))


def generate_customers(n=5000):
    records = []
    seen_emails = set()
    while len(records) < n:
        first = random.choice(FIRST_NAMES)
        last = random.choice(LAST_NAMES)
        email = f"{first.lower()}.{last.lower()}{random.randint(1, 9999)}@{random.choice(DOMAINS)}"
        if email in seen_emails:
            continue
        seen_emails.add(email)
        phone = f"({random.randint(200, 999)}) {random.randint(200, 999)}-{random.randint(1000, 9999)}"
        city, state = random.choice(CITIES_STATES)
        status = random.choice(STATUSES)
        total_orders = random.randint(0, 50)
        total_spent = round(random.uniform(0, 5000), 2)
        last_purchase = random.choice(PRODUCTS) if total_orders > 0 else None
        created_at = random_date()
        records.append((
            first, last, email, phone, city, state,
            status, total_orders, total_spent, last_purchase, created_at
        ))
    return records


def main():
    parser = argparse.ArgumentParser(description="Populate source RDS (PostgreSQL) with 5K customer records")
    parser.add_argument("--host", required=True, help="Source RDS endpoint")
    parser.add_argument("--port", type=int, default=5432)
    parser.add_argument("--user", default="dmsuser")
    parser.add_argument("--password", required=True)
    parser.add_argument("--database", default="dmsdb")
    parser.add_argument("--records", type=int, default=5000)
    args = parser.parse_args()

    print(f"Connecting to {args.host}:{args.port}/{args.database} ...")
    conn = psycopg2.connect(
        host=args.host,
        port=args.port,
        user=args.user,
        password=args.password,
        dbname=args.database,
    )
    conn.autocommit = False
    cursor = conn.cursor()

    cursor.execute("""
        CREATE TABLE IF NOT EXISTS customers (
            id            SERIAL PRIMARY KEY,
            first_name    VARCHAR(50)   NOT NULL,
            last_name     VARCHAR(50)   NOT NULL,
            email         VARCHAR(150)  NOT NULL UNIQUE,
            phone         VARCHAR(20),
            city          VARCHAR(100),
            state         VARCHAR(10),
            status        VARCHAR(20)   DEFAULT 'active'
                              CHECK (status IN ('active','inactive','pending','suspended')),
            total_orders  INT           DEFAULT 0,
            total_spent   NUMERIC(10,2) DEFAULT 0.00,
            last_purchase VARCHAR(100),
            created_at    TIMESTAMP     DEFAULT CURRENT_TIMESTAMP
        )
    """)
    conn.commit()
    print("Table 'customers' ready.")

    print(f"Generating {args.records} records...")
    records = generate_customers(args.records)

    insert_sql = """
        INSERT INTO customers
            (first_name, last_name, email, phone, city, state,
             status, total_orders, total_spent, last_purchase, created_at)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
    """

    batch_size = 500
    inserted = 0
    for i in range(0, len(records), batch_size):
        batch = records[i:i + batch_size]
        cursor.executemany(insert_sql, batch)
        conn.commit()
        inserted += len(batch)
        print(f"  Inserted {inserted}/{args.records} records...")

    cursor.execute("SELECT COUNT(*) FROM customers")
    total = cursor.fetchone()[0]
    print(f"\nDone. Total rows in customers table: {total}")

    cursor.close()
    conn.close()


if __name__ == "__main__":
    main()
