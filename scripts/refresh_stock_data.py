import yfinance as yf
import pandas as pd
import snowflake.connector
import os
from datetime import datetime, timedelta

# ── Connect to Snowflake ─────────────────────────────────────
conn = snowflake.connector.connect(
    account=os.environ["SNOWFLAKE_ACCOUNT"],
    user=os.environ["SNOWFLAKE_USER"],
    password=os.environ["SNOWFLAKE_PASSWORD"],
    warehouse=os.environ["SNOWFLAKE_WAREHOUSE"],
    database=os.environ["SNOWFLAKE_DATABASE"],
    schema=os.environ["SNOWFLAKE_SCHEMA"]
)

cursor = conn.cursor()

# ── Tickers ──────────────────────────────────────────────────
tickers = [
    # US Stocks
    "AAPL", "AMZN", "GOOGL", "MSFT", "TSLA", "SPY",
    # ASX ETFs
    "A200.AX", "ASIA.AX", "CRYP.AX", "HACK.AX", "NDQ.AX", "VAS.AX", "VGS.AX"
]

all_rows = []

for ticker in tickers:
    cursor.execute(f"""
        SELECT COALESCE(MAX(date), '2021-12-31')
        FROM stock_analytics.raw.raw_stock_prices
        WHERE ticker = '{ticker}'
    """)
    last_date = cursor.fetchone()[0]
    start_date = (pd.Timestamp(last_date) + timedelta(days=1)).strftime('%Y-%m-%d')
    end_date = datetime.today().strftime('%Y-%m-%d')

    print(f"{ticker}: fetching from {start_date} to {end_date}")

    if start_date >= end_date:
        print(f"{ticker}: already up to date. Skipping.")
        continue

    df = yf.download(ticker, start=start_date, end=end_date, auto_adjust=True)

    if df.empty:
        print(f"{ticker}: no data returned. Skipping.")
        continue

    df = df.reset_index()
    df.columns = [c[0].lower() if isinstance(c, tuple) else c.lower() for c in df.columns]
    df["ticker"] = ticker
    df = df[["date", "close", "high", "low", "open", "volume", "ticker"]]
    df["date"] = df["date"].astype(str)

    all_rows.append(df)
    print(f"{ticker}: fetched {len(df)} rows")

# ── Load into Snowflake using MERGE ──────────────────────────
if not all_rows:
    print("No new data to load.")
    cursor.close()
    conn.close()
    exit()

combined = pd.concat(all_rows)

# Create a temp table to stage incoming data
cursor.execute("""
    CREATE OR REPLACE TEMPORARY TABLE stock_analytics.raw.raw_stock_prices_temp (
        date    VARCHAR,
        close   FLOAT,
        high    FLOAT,
        low     FLOAT,
        open    FLOAT,
        volume  FLOAT,
        ticker  VARCHAR
    )
""")

# Insert new data into temp table
insert_sql = """
    INSERT INTO stock_analytics.raw.raw_stock_prices_temp
    (date, close, high, low, open, volume, ticker)
    VALUES (%s, %s, %s, %s, %s, %s, %s)
"""
rows = combined.values.tolist()
cursor.executemany(insert_sql, rows)
print(f"Staged {len(rows)} rows in temp table")

# MERGE from temp into raw — only insert if ticker+date doesn't exist
cursor.execute("""
    MERGE INTO stock_analytics.raw.raw_stock_prices AS target
    USING stock_analytics.raw.raw_stock_prices_temp AS source
        ON target.ticker = source.ticker
        AND target.date = TRY_TO_DATE(source.date)
    WHEN NOT MATCHED THEN INSERT (
        date, close, high, low, open, volume, ticker
    ) VALUES (
        TRY_TO_DATE(source.date),
        source.close,
        source.high,
        source.low,
        source.open,
        source.volume,
        source.ticker
    )
""")

# Get rows inserted
cursor.execute("SELECT COUNT(*) FROM stock_analytics.raw.raw_stock_prices_temp")
staged = cursor.fetchone()[0]
conn.commit()
print(f"MERGE complete — {staged} rows staged, duplicates automatically skipped")
print(f"Tickers updated: {combined['ticker'].unique().tolist()}")

# Force immediate refresh of Dynamic Tables
cursor.execute("ALTER DYNAMIC TABLE stock_analytics.staging.stg_stock_prices REFRESH")
print("Staging refreshed")
cursor.execute("ALTER DYNAMIC TABLE stock_analytics.analytics.fact_daily_returns REFRESH")
print("Fact table refreshed")

cursor.close()
conn.close()
print("Pipeline complete!")
