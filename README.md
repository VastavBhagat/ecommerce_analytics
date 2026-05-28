# E-Commerce Sales Analytics Platform

[![dbt CI](https://github.com/VastavBhagat/ecommerce_analytics/actions/workflows/dbt_ci.yml/badge.svg)](https://github.com/VastavBhagat/ecommerce_analytics/actions/workflows/dbt_ci.yml)

A full-stack data engineering project built on the Brazilian E-Commerce (Olist) public dataset. The pipeline pulls raw transaction data from Kaggle, loads it into Snowflake through Azure Data Lake, transforms it with dbt, and serves the results to a Power BI dashboard.

Built this to replicate what a data pipeline looks like at a real retail company - proper medallion storage, a star schema, automated tests, and a CI workflow that runs on every commit.

---

## Stack

| Layer | Tool |
|---|---|
| Source | Brazilian E-Commerce Dataset (Kaggle / Olist) |
| Ingestion | Azure Data Factory |
| Storage | Azure Data Lake Storage Gen2 (bronze / silver / gold) |
| Warehouse | Snowflake |
| Transformation | dbt Cloud |
| CI/CD | GitHub Actions |
| Dashboard | Power BI |

---

## Architecture

```
Kaggle API  ->  Azure Data Factory  ->  ADLS Gen2
                                        |-- bronze/   raw CSVs, no changes
                                        |-- silver/   ADF staging zone
                                              |
                                         COPY INTO (SAS token)
                                              |
                                          Snowflake
                                          |-- RAW_DB           6 raw tables
                                          |-- ANALYTICS_DB
                                              |-- STAGING       dbt views
                                              |-- MARTS         dbt tables
                                                    |
                                            Power BI Dashboard
```

ADF downloads and decompresses the Kaggle zip in a single Copy activity using ZipDeflate, writing all CSVs directly into the bronze container. Snowflake reads from an external stage pointing to ADLS and loads each table with COPY INTO.

---

## Numbers

- 500,000+ rows loaded across 6 source tables
- 6 staging models + 3 mart models
- 11 data quality tests, all passing
- CI pipeline runs in about 42 seconds
- R$13.59M total revenue in the dataset

---

## dbt Models

Three layers:

**Sources** reference raw tables in `RAW_DB.ECOMMERCE` - no transformations, just lineage anchors.

**Staging** (views in `ANALYTICS_DB.STAGING`) cleans the raw data - renames columns to snake_case, casts types, normalises categoricals, and computes derived fields like `delivery_days` and `delivered_on_time`.

**Marts** (tables in `ANALYTICS_DB.MARTS`) are the analytical layer:

| Model | Description |
|---|---|
| `fact_orders` | One row per order with revenue, freight, item count, and delivery metrics |
| `dim_customers` | One row per customer with order history, lifetime value, and an RFM-style segment |
| `dim_products` | One row per product with total revenue and average selling price |

Lineage:

```
raw_orders          ->  stg_orders         -+->  fact_orders  ->  dim_customers
raw_order_items     ->  stg_order_items     -+
raw_customers       ->  stg_customers       -------->  dim_customers
raw_products        ->  stg_products        ---------->  dim_products
raw_sellers         ->  stg_sellers         (staged, available for seller analytics)
raw_order_payments  ->  stg_payments        (staged, available for payment analytics)

stg_order_items  ------------------------------>  dim_products
```

Customer segments assigned in `dim_customers`:

| Segment | Condition |
|---|---|
| `churned` | No orders in the last 180 days |
| `at risk` | No orders in 90-180 days |
| `loyal` | More than 3 lifetime orders |
| `active` | Ordered within the last 90 days |
| `never_ordered` | Customer record exists but no associated orders |

---

## Data Quality Tests

11 tests run automatically on every push:

| Model | Column | Tests |
|---|---|---|
| `fact_orders` | `order_id` | unique, not_null |
| `fact_orders` | `customer_id` | not_null, relationships (-> dim_customers) |
| `fact_orders` | `revenue` | not_null |
| `fact_orders` | `order_status` | accepted_values (8 statuses) |
| `dim_customers` | `customer_id` | unique, not_null |
| `dim_customers` | `customer_segment` | accepted_values (5 segments) |
| `dim_products` | `product_id` | unique, not_null |

---

## Findings

A few things that stood out from the data:

Health and beauty (`beleza_saude`) is the top revenue category at R$1.26M, followed closely by watches and gifts at R$1.21M. The top 10 categories account for roughly 70% of total platform revenue.

Average delivery time is 12.5 days but varies quite a bit by state, which points to differences in regional logistics infrastructure.

A large portion of customers are in the `churned` or `at risk` segments - no activity in 90+ days. The segmentation in `dim_customers` is directly usable for a re-engagement campaign.

Monthly revenue peaked in May 2018 at around R$1.5M, then dropped off sharply in August and September as the dataset coverage period ended.

---

## Things That Needed Debugging

Stuff that wasn't obvious from the docs and took actual trial and error:

**ADF zip extraction** - ADF's HTTP connector does not support random read access, so downloading first and unzipping in a second step does not work. You have to set ZipDeflate compression on the source dataset and use a single Copy activity. Also need Flatten hierarchy on the sink, otherwise ADF recreates Kaggle's internal folder structure inside the container.

**Snowflake stage auth** - The SAS token has to be container-level, not account-level. When generating it you need Blob service selected with both Container and Object resource types, plus Read and List permissions. Using account-level SAS fails silently with a permissions error on the stage.

**dbt Fusion syntax** - dbt Fusion 2.0 requires `data_tests:` instead of the old `tests:` key. For `accepted_values` and `relationships`, the parameters need to go under an `arguments:` key. The old syntax breaks without a very clear error message.

**GitHub Actions profiles.yml** - Writing the profiles file with a heredoc and GitHub secrets does not work cleanly because of how variable expansion interacts with quoted EOF delimiters. Writing each line separately with echo and `${{ secrets.NAME }}` is the approach that works consistently.

---

## Project Structure

```
ecommerce_analytics/
├── .github/
│   └── workflows/
│       └── dbt_ci.yml
├── models/
│   ├── staging/
│   │   ├── sources.yml
│   │   ├── stg_orders.sql
│   │   ├── stg_order_items.sql
│   │   ├── stg_customers.sql
│   │   ├── stg_products.sql
│   │   ├── stg_sellers.sql
│   │   └── stg_payments.sql
│   └── marts/
│       ├── fact_orders.sql
│       ├── dim_customers.sql
│       ├── dim_products.sql
│       └── schema.yml
├── dbt_project.yml
└── README.md
```

---

## Running This Locally

You need a Snowflake account with `RAW_DB` and `ANALYTICS_DB` set up, and ADLS Gen2 with the bronze container populated via the ADF pipeline.

```bash
pip install dbt-snowflake
```

Create `~/.dbt/profiles.yml` with your Snowflake credentials. The profile name needs to be `ecommerce_analytics` to match `dbt_project.yml`.

```bash
dbt debug   # check the connection
dbt run     # build all models
dbt test    # run quality tests
```

For CI, add `SNOWFLAKE_ACCOUNT`, `SNOWFLAKE_USER`, and `SNOWFLAKE_PASSWORD` as repository secrets in GitHub. The workflow runs automatically on every push to `main`.

---

Dataset: [Brazilian E-Commerce Public Dataset by Olist](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce)
