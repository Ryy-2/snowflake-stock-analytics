-- ============================================================
-- FILE: 05_views.sql
-- PURPOSE: Create analytical views for reporting and visualisation
-- Views: stock performance, monthly returns, MA crossover, yearly summary
-- ============================================================

USE SCHEMA stock_analytics.analytics;
USE WAREHOUSE stock_wh;

-- ------------------------------------------------------------
-- VIEW 1: Overall stock performance summary
-- Shows best/worst days, average return, and volatility per ticker
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW stock_analytics.analytics.v_stock_performance AS
SELECT
    ticker,
    ROUND(MIN(close), 2)            AS lowest_price,
    ROUND(MAX(close), 2)            AS highest_price,
    ROUND(MAX(close) - MIN(close), 2) AS price_range,
    MAX(daily_return_pct)           AS best_single_day,
    MIN(daily_return_pct)           AS worst_single_day,
    ROUND(AVG(daily_return_pct), 4) AS avg_daily_return,
    ROUND(AVG(volatility_30day), 4) AS avg_volatility,
    SUM(volume)                     AS total_volume
FROM stock_analytics.analytics.fact_daily_returns
WHERE daily_return_pct IS NOT NULL
GROUP BY ticker
ORDER BY avg_daily_return DESC;

SELECT * FROM stock_analytics.analytics.v_stock_performance;

-- ------------------------------------------------------------
-- VIEW 2: Monthly returns per ticker
-- Useful for identifying seasonal trends
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW stock_analytics.analytics.v_monthly_returns AS
SELECT
    ticker,
    DATE_TRUNC('month', date)                                           AS month,
    ROUND(MIN(close), 2)                                                AS month_low,
    ROUND(MAX(close), 2)                                                AS month_high,
    ROUND(AVG(close), 2)                                                AS avg_close,
    SUM(volume)                                                         AS monthly_volume,
    ROUND(((MAX(close) - MIN(close)) / NULLIF(MIN(close), 0)) * 100, 2) AS monthly_return_pct
FROM stock_analytics.analytics.fact_daily_returns
GROUP BY ticker, DATE_TRUNC('month', date)
ORDER BY ticker, month;

SELECT * FROM stock_analytics.analytics.v_monthly_returns LIMIT 20;

-- ------------------------------------------------------------
-- VIEW 3: Moving average crossover signal
-- BULLISH = 7-day MA crosses above 30-day MA (potential buy signal)
-- BEARISH = 7-day MA crosses below 30-day MA (potential sell signal)
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW stock_analytics.analytics.v_ma_crossover AS
SELECT
    date,
    ticker,
    close,
    ma_7day,
    ma_30day,
    CASE
        WHEN ma_7day > ma_30day THEN 'BULLISH'
        WHEN ma_7day < ma_30day THEN 'BEARISH'
        ELSE 'NEUTRAL'
    END AS signal,
    LAG(CASE
        WHEN ma_7day > ma_30day THEN 'BULLISH'
        WHEN ma_7day < ma_30day THEN 'BEARISH'
        ELSE 'NEUTRAL'
    END) OVER (PARTITION BY ticker ORDER BY date) AS prev_signal
FROM stock_analytics.analytics.fact_daily_returns
WHERE ma_30day IS NOT NULL;

-- Show only crossover dates (when signal changes)
SELECT date, ticker, close, ma_7day, ma_30day, signal
FROM stock_analytics.analytics.v_ma_crossover
WHERE signal != prev_signal
ORDER BY ticker, date;

-- ------------------------------------------------------------
-- VIEW 4: Yearly summary per ticker
-- High level overview of price range and volatility by year
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW stock_analytics.analytics.v_yearly_summary AS
SELECT
    ticker,
    YEAR(date)                      AS year,
    ROUND(MIN(close), 2)            AS year_low,
    ROUND(MAX(close), 2)            AS year_high,
    ROUND(AVG(close), 2)            AS avg_close,
    ROUND(AVG(volatility_30day), 4) AS avg_volatility,
    SUM(volume)                     AS total_volume
FROM stock_analytics.analytics.fact_daily_returns
GROUP BY ticker, YEAR(date)
ORDER BY ticker, year;

SELECT * FROM stock_analytics.analytics.v_yearly_summary;
