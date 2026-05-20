-- ============================================================
-- FILE: 03_staging.sql
-- PURPOSE: Clean and standardise raw stock data
-- Adds daily change and daily change % columns
-- ============================================================

USE SCHEMA stock_analytics.staging;
USE WAREHOUSE stock_wh;

-- ------------------------------------------------------------
-- Create staging table: cleaned version of raw data
-- Filters out nulls and adds basic derived columns
-- ------------------------------------------------------------
CREATE OR REPLACE TABLE stock_analytics.staging.stg_stock_prices AS
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
WHERE date IS NOT NULL
  AND close IS NOT NULL
ORDER BY ticker, date;

-- ------------------------------------------------------------
-- Verify
-- ------------------------------------------------------------
SELECT * FROM stock_analytics.staging.stg_stock_prices LIMIT 10;
