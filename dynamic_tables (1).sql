-- ============================================================
-- FILE: 07_dynamic_tables.sql
-- PURPOSE: Reference file — Dynamic Tables are now defined in
--          03_staging.sql and 04_fact_table.sql
-- Run this only if you need to rebuild both Dynamic Tables
-- ============================================================

USE WAREHOUSE stock_wh;

-- ── STEP 1: Rebuild staging Dynamic Table ────────────────────
DROP DYNAMIC TABLE IF EXISTS stock_analytics.staging.stg_stock_prices;
DROP TABLE IF EXISTS stock_analytics.staging.stg_stock_prices;

CREATE OR REPLACE DYNAMIC TABLE stock_analytics.staging.stg_stock_prices
    TARGET_LAG = '1 day'
    WAREHOUSE  = stock_wh
    INITIALIZE = 'ON_CREATE'
AS
SELECT
    date, ticker, open, high, low, close, volume,
    ROUND(close - open, 2)                              AS daily_change,
    ROUND(((close - open) / NULLIF(open, 0)) * 100, 2) AS daily_change_pct
FROM stock_analytics.raw.raw_stock_prices
WHERE date IS NOT NULL AND close IS NOT NULL;

-- ── STEP 2: Rebuild fact Dynamic Table ───────────────────────
DROP DYNAMIC TABLE IF EXISTS stock_analytics.analytics.fact_daily_returns;
DROP TABLE IF EXISTS stock_analytics.analytics.fact_daily_returns;

CREATE OR REPLACE DYNAMIC TABLE stock_analytics.analytics.fact_daily_returns
    TARGET_LAG = '1 day'
    WAREHOUSE  = stock_wh
    INITIALIZE = 'ON_CREATE'
AS
SELECT
    date, ticker, open, high, low, close, volume, daily_change, daily_change_pct,
    ROUND(AVG(close) OVER (PARTITION BY ticker ORDER BY date ROWS BETWEEN 6  PRECEDING AND CURRENT ROW), 2) AS ma_7day,
    ROUND(AVG(close) OVER (PARTITION BY ticker ORDER BY date ROWS BETWEEN 29 PRECEDING AND CURRENT ROW), 2) AS ma_30day,
    LAG(close, 1) OVER (PARTITION BY ticker ORDER BY date) AS prev_close,
    ROUND(((close - LAG(close,1) OVER (PARTITION BY ticker ORDER BY date)) / NULLIF(LAG(close,1) OVER (PARTITION BY ticker ORDER BY date),0))*100,2) AS daily_return_pct,
    ROUND(STDDEV(daily_change_pct) OVER (PARTITION BY ticker ORDER BY date ROWS BETWEEN 29 PRECEDING AND CURRENT ROW),4) AS volatility_30day
FROM stock_analytics.staging.stg_stock_prices
WHERE ticker != 'SPY';

-- ── STEP 3: Verify ───────────────────────────────────────────
SELECT ticker, COUNT(*) AS row_count, MIN(date) AS first_date
FROM stock_analytics.staging.stg_stock_prices
GROUP BY ticker ORDER BY ticker;

SELECT ticker, COUNT(*) AS row_count, MIN(date) AS first_date
FROM stock_analytics.analytics.fact_daily_returns
GROUP BY ticker ORDER BY ticker;