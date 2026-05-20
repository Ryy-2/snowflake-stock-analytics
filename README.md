# 📈 Stock Market Analytics Pipeline

An end-to-end data engineering and analytics project built on Snowflake, featuring automated daily data ingestion, multi-layer SQL transformations, and a live interactive dashboard.

![Snowflake](https://img.shields.io/badge/Snowflake-29B5E8?style=flat&logo=snowflake&logoColor=white)
![Python](https://img.shields.io/badge/Python-3776AB?style=flat&logo=python&logoColor=white)
![GitHub Actions](https://img.shields.io/badge/GitHub_Actions-2088FF?style=flat&logo=github-actions&logoColor=white)
![Streamlit](https://img.shields.io/badge/Streamlit-FF4B4B?style=flat&logo=streamlit&logoColor=white)

---

## 🗂 Project Overview

This project simulates a real-world data engineering pipeline for stock market analytics. It ingests historical and live price data for 5 major tech companies, transforms it through a layered Snowflake architecture, and visualises key insights in a Streamlit dashboard — all refreshed automatically every weekday.

**Tickers covered:** AAPL, AMZN, GOOGL, MSFT, TSLA

**Date range:** January 2022 — Present (live updates daily)

---

## 🏗 Architecture

```
┌─────────────────────────────────────────────────────────┐
│                     DATA SOURCES                        │
│              Yahoo Finance (via yfinance)               │
└─────────────────────┬───────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────┐
│                   ORCHESTRATION                         │
│         GitHub Actions — runs weekdays at 6am           │
│         Python script fetches & appends new rows        │
└─────────────────────┬───────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────┐
│                  SNOWFLAKE LAYERS                       │
│                                                         │
│  RAW SCHEMA                                             │
│  └── raw_stock_prices     (source of truth)             │
│                                                         │
│  STAGING SCHEMA  [Dynamic Table]                        │
│  └── stg_stock_prices     (cleaned + daily change %)    │
│                                                         │
│  ANALYTICS SCHEMA  [Dynamic Table]                      │
│  ├── fact_daily_returns   (moving averages, returns)    │
│  ├── v_stock_performance  (performance summary view)    │
│  ├── v_monthly_returns    (monthly breakdown view)      │
│  ├── v_ma_crossover       (buy/sell signal view)        │
│  └── v_yearly_summary     (year-over-year view)         │
└─────────────────────┬───────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────┐
│               VISUALISATION                             │
│         Streamlit in Snowflake — Live Dashboard         │
└─────────────────────────────────────────────────────────┘
```

---

## 🛠 Tech Stack

| Tool | Purpose |
|---|---|
| **Snowflake** | Cloud data warehouse — storage, compute, transformation |
| **Python + yfinance** | Stock data extraction from Yahoo Finance |
| **GitHub Actions** | Automated daily pipeline orchestration |
| **Snowflake Dynamic Tables** | Auto-refreshing staging and analytics layers |
| **Streamlit in Snowflake** | Interactive live dashboard |
| **SQL Window Functions** | Moving averages, rolling volatility, return calculations |

---

## 📊 Key Analytics

| Metric | Description |
|---|---|
| **7-day Moving Average** | Short-term price trend |
| **30-day Moving Average** | Long-term price trend |
| **Daily Return %** | Day-over-day price change percentage |
| **30-day Rolling Volatility** | Standard deviation of daily returns over 30 days |
| **MA Crossover Signal** | Bullish/Bearish signal when 7-day crosses 30-day MA |
| **Monthly Returns** | Price range and return % by month |
| **Yearly Summary** | High, low, average close, and total volume by year |

---

## 📁 File Structure

```
snowflake-stock-analytics/
│
├── .github/
│   └── workflows/
│       └── daily_refresh.yml       # GitHub Actions workflow (runs weekdays 6am AEST)
│
├── scripts/
│   └── refresh_stock_data.py       # Python script to fetch and load new stock data
│
├── sql/
│   ├── 1_setup/
│   │   └── 01_setup.sql            # Database, schemas, warehouse
│   ├── 2_raw/
│   │   └── 02_raw.sql              # Stage, temp table, raw table, data load
│   ├── 3_staging/
│   │   └── 03_staging.sql          # Cleaned staging table
│   └── 4_analytics/
│       ├── 04_fact_table.sql       # Core analytics fact table with window functions
│       ├── 05_views.sql            # Analytical views
│       └── 07_dynamic_tables.sql   # Dynamic tables for auto-refresh
│
└── README.md
```

---

## 🚀 How to Run

### Prerequisites
- Snowflake account (free trial at snowflake.com)
- GitHub account
- Python 3.9+

### Steps

**1. Set up Snowflake**
```sql
-- Run in order:
sql/1_setup/01_setup.sql
sql/2_raw/02_raw.sql
sql/3_staging/03_staging.sql
sql/4_analytics/04_fact_table.sql
sql/4_analytics/05_views.sql
sql/4_analytics/07_dynamic_tables.sql
```

**2. Add GitHub Secrets**

Go to your repo → Settings → Secrets and variables → Actions and add:

| Secret | Value |
|---|---|
| `SNOWFLAKE_ACCOUNT` | Your Snowflake account identifier |
| `SNOWFLAKE_USER` | Your Snowflake username |
| `SNOWFLAKE_PASSWORD` | Your Snowflake password |
| `SNOWFLAKE_WAREHOUSE` | `stock_wh` |
| `SNOWFLAKE_DATABASE` | `stock_analytics` |
| `SNOWFLAKE_SCHEMA` | `raw` |

**3. Run the pipeline manually**

Go to Actions → Daily Stock Data Refresh → Run workflow

**4. Launch the Streamlit dashboard**

In Snowsight go to Streamlit → stock_analytics_dashboard → Run

---

## 💡 SQL Concepts Demonstrated

- `COPY INTO` — bulk loading CSV data via internal stage
- `UNION ALL` — unpivoting wide CSV format into long format
- `AVG() OVER()` — 7-day and 30-day moving averages
- `LAG()` — previous day price comparison
- `STDDEV() OVER()` — 30-day rolling volatility
- `DATE_TRUNC()` — monthly and yearly aggregations
- `TRY_TO_DATE / TRY_TO_DOUBLE` — safe type casting
- `NULLIF` — division by zero protection
- `DYNAMIC TABLES` — automatic downstream refresh
- `VIEWS` — reusable analytical query layers

---

## 🔄 Automation Schedule

The GitHub Actions workflow runs automatically:
- **Schedule:** Monday to Friday at 6:00am AEST
- **Action:** Fetches new trading day data from Yahoo Finance
- **Result:** Appends new rows to `raw_stock_prices` → Dynamic Tables cascade the refresh through staging and analytics automatically

---

## 📬 Contact

Built by **Pinary** as part of a data engineering portfolio project.
