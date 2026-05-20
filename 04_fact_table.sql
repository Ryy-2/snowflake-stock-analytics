-- ============================================================
-- FILE: 04_fact_table.sql
-- PURPOSE: Build analytics fact table with window functions
-- Calculates moving averages, daily returns, and volatility
-- ============================================================

USE SCHEMA stock_analytics.analytics;
USE WAREHOUSE stock_wh;

-- ------------------------------------------------------------
-- fact_daily_returns: core analytics table
-- Window functions used:
--   AVG() OVER()  -> moving averages (7-day, 30-day)
--   LAG()         -> previous day close price
--   STDDEV() OVER() -> rolling 30-day volatility
-- ------------------------------------------------------------
CREATE OR REPLACE TABLE stock_analytics.analytics.fact_daily_returns AS
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

    -- 7-day moving average of close price
    ROUND(AVG(close) OVER (
        PARTITION BY ticker
        ORDER BY date
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ), 2) AS ma_7day,

    -- 30-day moving average of close price
    ROUND(AVG(close) OVER (
        PARTITION BY ticker
        ORDER BY date
        ROWS BETWEEN 29 PRECEDING AND CURRENT ROW
    ), 2) AS ma_30day,

    -- Previous day closing price
    LAG(close, 1) OVER (
        PARTITION BY ticker ORDER BY date
    ) AS prev_close,

    -- Daily return % compared to previous day close
    ROUND(
        ((close - LAG(close, 1) OVER (PARTITION BY ticker ORDER BY date))
        / NULLIF(LAG(close, 1) OVER (PARTITION BY ticker ORDER BY date), 0)) * 100
    , 2) AS daily_return_pct,

    -- 30-day rolling volatility (standard deviation of daily change %)
    ROUND(STDDEV(daily_change_pct) OVER (
        PARTITION BY ticker
        ORDER BY date
        ROWS BETWEEN 29 PRECEDING AND CURRENT ROW
    ), 4) AS volatility_30day

FROM stock_analytics.staging.stg_stock_prices
ORDER BY ticker, date;

-- ------------------------------------------------------------
-- Verify
-- ------------------------------------------------------------
SELECT
    date,
    ticker,
    close,
    ma_7day,
    ma_30day,
    daily_return_pct,
    volatility_30day
FROM stock_analytics.analytics.fact_daily_returns
WHERE ticker = 'AAPL'
ORDER BY date
LIMIT 10;
