-- ============================================================
-- FILE: 03_staging.sql
-- PURPOSE: Clean and standardise raw stock data
-- Dynamic Table auto-refreshes within 1 day when raw data updates
-- Includes SPY for benchmark comparison
-- ============================================================

USE WAREHOUSE stock_wh;

-- Drop any existing table or dynamic table
DROP TABLE IF EXISTS stock_analytics.staging.stg_stock_prices;
DROP DYNAMIC TABLE IF EXISTS stock_analytics.staging.stg_stock_prices;

-- Staging Dynamic Table: cleaned version of raw data
-- Auto-refreshes when raw_stock_prices receives new rows
CREATE OR REPLACE DYNAMIC TABLE stock_analytics.staging.stg_stock_prices
    TARGET_LAG = '1 day'
    WAREHOUSE  = stock_wh
    INITIALIZE = 'ON_CREATE'
AS
SELECT
    date,
    ticker,
    open,
    high,
    low,
    close,
    volume,
    ROUND(close - open, 2)                              AS daily_change,
    ROUND(((close - open) / NULLIF(open, 0)) * 100, 2) AS daily_change_pct
FROM stock_analytics.raw.raw_stock_prices
WHERE date  IS NOT NULL
  AND close IS NOT NULL;

-- Verify
SELECT ticker, COUNT(*) AS row_count, MIN(date) AS first_date, MAX(date) AS latest_date
FROM stock_analytics.staging.stg_stock_prices
GROUP BY ticker
ORDER BY ticker;