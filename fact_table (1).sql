-- ============================================================
-- FILE: 04_fact_table.sql
-- PURPOSE: Build core analytics fact table using window functions
-- Dynamic Table auto-refreshes within 1 day when staging updates
-- Excludes SPY (SPY handled separately in benchmark view)
-- ============================================================

USE WAREHOUSE stock_wh;

-- Drop any existing table or dynamic table
DROP TABLE IF EXISTS stock_analytics.analytics.fact_daily_returns;
DROP DYNAMIC TABLE IF EXISTS stock_analytics.analytics.fact_daily_returns;

-- fact_daily_returns: core analytics Dynamic Table
-- Window functions:
--   AVG() OVER()    → 7-day and 30-day moving averages
--   LAG()           → previous day close price
--   STDDEV() OVER() → 30-day rolling volatility
CREATE OR REPLACE DYNAMIC TABLE stock_analytics.analytics.fact_daily_returns
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
    daily_change,
    daily_change_pct,

    -- 7-day moving average
    ROUND(AVG(close) OVER (
        PARTITION BY ticker ORDER BY date
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ), 2) AS ma_7day,

    -- 30-day moving average
    ROUND(AVG(close) OVER (
        PARTITION BY ticker ORDER BY date
        ROWS BETWEEN 29 PRECEDING AND CURRENT ROW
    ), 2) AS ma_30day,

    -- Previous day close
    LAG(close, 1) OVER (
        PARTITION BY ticker ORDER BY date
    ) AS prev_close,

    -- Daily return % vs previous day
    ROUND(
        ((close - LAG(close, 1) OVER (PARTITION BY ticker ORDER BY date))
        / NULLIF(LAG(close, 1) OVER (PARTITION BY ticker ORDER BY date), 0)) * 100
    , 2) AS daily_return_pct,

    -- 30-day rolling volatility
    ROUND(STDDEV(daily_change_pct) OVER (
        PARTITION BY ticker ORDER BY date
        ROWS BETWEEN 29 PRECEDING AND CURRENT ROW
    ), 4) AS volatility_30day

FROM stock_analytics.staging.stg_stock_prices
WHERE ticker != 'SPY';

-- Verify
SELECT ticker, COUNT(*) AS row_count, MIN(date) AS first_date, MAX(date) AS latest_date
FROM stock_analytics.analytics.fact_daily_returns
GROUP BY ticker
ORDER BY ticker;