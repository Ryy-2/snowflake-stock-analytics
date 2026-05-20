import yfinance as yf
import pandas as pd
import snowflake.connector
import os
from datetime import datetime, timedelta

# Connect to Snowflake using environment variables
conn = snowflake.connector.connect(
    account=os.environ["SNOWFLAKE_ACCOUNT"],
    user=os.environ["SNOWFLAKE_USER"],
    password=os.environ["SNOWFLAKE_PASSWORD"],
    warehouse=os.environ["SNOWFLAKE_WAREHOUSE"],
    database=os.environ["SNOWFLAKE_DATABASE"],
    schema=os.environ["SNOWFLAKE_SCHEMA"]
)

cursor = conn.cursor()

# Get the latest date already in Snowflake
cursor.execute("""
    SELECT COALESCE(MAX(date), '2024-12-31')
    FROM stock_analytics.raw.raw_stock_prices
""")
last_date = cursor.fetchone()[0]
start_date = (pd.Timestamp(last_date) + timedelta(days=1)).strftime('%Y-%m-%d')
end_date = datetime.today().strftime('%Y-%m-%d')

print(f"Fetching data from {start_date} to {end_date}")

if start_date >= end_date:
    print("Already up to date. No new data to load.")
    conn.close()
    exit()

# Fetch new data from Yahoo Finance
tickers = ["AAPL", "AMZN", "GOOGL", "MSFT", "TSLA"]
all_rows = []

for ticker in tickers:
    df = yf.download(ticker, start=start_date, end=end_date, auto_adjust=True)
    if df.empty:
        print(f"No new data for {ticker}")
        continue
    df = df.reset_index()
    df.columns = [c.lower().replace(" ", "_") for c in df.columns]
    df["ticker"] = ticker
    all_rows.append(df[["date", "close", "high", "low", "open", "volume", "ticker"]])
    print(f"Fetched {len(df)} rows for {ticker}")

if not all_rows:
    print("No new data available.")
    conn.close()
    exit()

combined = pd.concat(all_rows)
combined["date"] = combined["date"].astype(str)

# Insert new rows into Snowflake
insert_sql = """
    INSERT INTO stock_analytics.raw.raw_stock_prices
    (date, close, high, low, open, volume, ticker)
    VALUES (%s, %s, %s, %s, %s, %s, %s)
"""

rows = combined.values.tolist()
cursor.executemany(insert_sql, rows)
conn.commit()

print(f"Successfully loaded {len(rows)} new rows into Snowflake")
cursor.close()
conn.close()
