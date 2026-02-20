"""
generate_tables.py

Creates two Delta Lake tables for a dashboard demo:
  .data/customers   — 10,000 customer records
  .data/orders      — ~50,000 order line-items (join on customer_id)

Run:
    python generate_tables.py
"""

import os
import random
import shutil
from pathlib import Path
from datetime import datetime, timedelta

import pandas as pd
from faker import Faker
from deltalake import write_deltalake

fake = Faker("en_US")
random.seed(42)
Faker.seed(42)

# ── Config ────────────────────────────────────────────────────────────────────

N_CUSTOMERS = 10_000
N_ORDERS    = 50_000          # each order has 1–4 line items → ~75–100k rows

OUTPUT_DIR = Path(os.environ.get("DELTA_OUTPUT_DIR", "data"))

REGIONS     = ["North", "South", "East", "West", "Midwest"]
SEGMENTS    = ["Consumer", "Corporate", "Home Office"]
CATEGORIES  = ["Technology", "Furniture", "Office Supplies"]
SUBCATEGORIES = {
    "Technology":       ["Phones", "Laptops", "Accessories", "Monitors"],
    "Furniture":        ["Chairs", "Tables", "Bookcases", "Storage"],
    "Office Supplies":  ["Paper", "Binders", "Art", "Fasteners", "Labels"],
}
STATUSES    = ["Delivered", "Shipped", "Processing", "Returned", "Cancelled"]
STATUS_WEIGHTS = [0.65, 0.15, 0.08, 0.07, 0.05]

# ── Helpers ───────────────────────────────────────────────────────────────────

def random_date(start: datetime, end: datetime) -> datetime:
    delta = end - start
    return start + timedelta(seconds=random.randint(0, int(delta.total_seconds())))


def clean_output(path: Path) -> None:
    if path.exists():
        shutil.rmtree(path)
        print(f"  Removed existing table at {path}")


# ── Customers ─────────────────────────────────────────────────────────────────

print("Generating customers table …")

start_date = datetime(2018, 1, 1)
end_date   = datetime(2024, 12, 31)

customers = []
for i in range(1, N_CUSTOMERS + 1):
    customers.append({
        "customer_id":   i,
        "name":          fake.name(),
        "email":         fake.email(),
        "city":          fake.city(),
        "state":         fake.state(),
        "region":        random.choice(REGIONS),
        "segment":       random.choice(SEGMENTS),
        "signup_date":   random_date(start_date, end_date).date().isoformat(),
        "is_active":     random.choices([True, False], weights=[0.85, 0.15])[0],
    })

customers_df = pd.DataFrame(customers)

OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

clean_output(OUTPUT_DIR / "customers")
write_deltalake(str(OUTPUT_DIR / "customers"), customers_df)
print(f"  Written {len(customers_df):,} rows → {OUTPUT_DIR}/customers  (version 0)")


# ── Orders ────────────────────────────────────────────────────────────────────

print("Generating orders table …")

order_date_start = datetime(2020, 1, 1)
order_date_end   = datetime(2024, 12, 31)

order_rows = []
order_id   = 1

for _ in range(N_ORDERS):
    customer_id  = random.randint(1, N_CUSTOMERS)
    order_date   = random_date(order_date_start, order_date_end)
    ship_date    = order_date + timedelta(days=random.randint(1, 14))
    status       = random.choices(STATUSES, weights=STATUS_WEIGHTS)[0]
    n_items      = random.randint(1, 4)

    for _ in range(n_items):
        category    = random.choice(CATEGORIES)
        subcategory = random.choice(SUBCATEGORIES[category])
        quantity    = random.randint(1, 10)
        unit_price  = round(random.uniform(5.0, 1500.0), 2)
        discount    = round(random.choice([0.0, 0.05, 0.10, 0.15, 0.20, 0.30]), 2)
        revenue     = round(quantity * unit_price * (1 - discount), 2)
        cost        = round(revenue * random.uniform(0.4, 0.75), 2)
        profit      = round(revenue - cost, 2)

        order_rows.append({
            "order_line_id": len(order_rows) + 1,
            "order_id":      order_id,
            "customer_id":   customer_id,
            "order_date":    order_date.date().isoformat(),
            "ship_date":     ship_date.date().isoformat(),
            "status":        status,
            "category":      category,
            "subcategory":   subcategory,
            "product_name":  f"{fake.word().capitalize()} {subcategory[:-1]}",
            "quantity":      quantity,
            "unit_price":    unit_price,
            "discount":      discount,
            "revenue":       revenue,
            "cost":          cost,
            "profit":        profit,
        })

    order_id += 1

orders_df = pd.DataFrame(order_rows)

clean_output(OUTPUT_DIR / "orders")
write_deltalake(str(OUTPUT_DIR / "orders"), orders_df)
print(f"  Written {len(orders_df):,} rows → {OUTPUT_DIR}/orders  (version 0)")


# ── Summary ───────────────────────────────────────────────────────────────────

print()
print("Done! Tables ready for querying.")
print()
print("Example DuckDB queries:")
print()
print("  INSTALL delta; LOAD delta;")
print()
print("  CREATE TEMP VIEW customers AS")
print(f"    SELECT * FROM delta_scan('{OUTPUT_DIR}/customers');")
print()
print("  CREATE TEMP VIEW orders AS")
print(f"    SELECT * FROM delta_scan('{OUTPUT_DIR}/orders');")
print()
print("  -- Revenue by region and category")
print("  SELECT c.region, o.category,")
print("         ROUND(SUM(o.revenue), 2) AS total_revenue,")
print("         ROUND(SUM(o.profit),  2) AS total_profit")
print("  FROM orders o")
print("  JOIN customers c USING (customer_id)")
print("  GROUP BY c.region, o.category")
print("  ORDER BY total_revenue DESC;")
