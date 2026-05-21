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
tickers = ["AAPL", "AMZN", "GOOGL", "MSFT", "TSLA", "SPY"]

all_rows = []

for ticker in tickers:
    # Get last loaded date PER ticker so new tickers backfill from 2022
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
        print(f"{ticker}: no data returned from Yahoo Finance. Skipping.")
        continue

    df = df.reset_index()
    df.columns = [c[0].lower() if isinstance(c, tuple) else c.lower() for c in df.columns]
    df["ticker"] = ticker
    df = df[["date", "close", "high", "low", "open", "volume", "ticker"]]
    df["date"] = df["date"].astype(str)

    all_rows.append(df)
    print(f"{ticker}: fetched {len(df)} rows")

# ── Load into Snowflake ──────────────────────────────────────
if not all_rows:
    print("No new data to load across any ticker.")
    cursor.close()
    conn.close()
    exit()

combined = pd.concat(all_rows)

insert_sql = """
    INSERT INTO stock_analytics.raw.raw_stock_prices
    (date, close, high, low, open, volume, ticker)
    VALUES (%s, %s, %s, %s, %s, %s, %s)
"""

rows = combined.values.tolist()
cursor.executemany(insert_sql, rows)
conn.commit()

print(f"Successfully loaded {len(rows)} new rows into Snowflake")
print(f"Tickers updated: {combined['ticker'].unique().tolist()}")

cursor.close()
conn.close()
