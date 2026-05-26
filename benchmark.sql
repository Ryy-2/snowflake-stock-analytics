-- ============================================================
-- FILE: benchmark.sql
-- PURPOSE: Benchmark comparison views
--   v_benchmark_comparison     → US stocks vs SPY
--   v_asx_benchmark_comparison → ASX ETFs vs A200
-- ============================================================

USE SCHEMA stock_analytics.analytics;
USE WAREHOUSE stock_wh;

-- ── VIEW 1: US Stocks vs SPY ──────────────────────────────────
CREATE OR REPLACE VIEW stock_analytics.analytics.v_benchmark_comparison AS
WITH base_prices AS (
    SELECT ticker, MIN(date) AS base_date
    FROM stock_analytics.staging.stg_stock_prices
    WHERE date >= '2022-01-03'
    AND ticker IN ('AAPL', 'AMZN', 'GOOGL', 'MSFT', 'TSLA', 'SPY')
    GROUP BY ticker
),
first_close AS (
    SELECT r.ticker, r.close AS base_price, bp.base_date
    FROM stock_analytics.staging.stg_stock_prices r
    JOIN base_prices bp ON bp.ticker = r.ticker AND bp.base_date = r.date
),
indexed AS (
    SELECT
        r.date, r.ticker, r.close, fc.base_price,
        ROUND((r.close / NULLIF(fc.base_price, 0)) * 100, 4) AS indexed_price
    FROM stock_analytics.staging.stg_stock_prices r
    JOIN first_close fc ON fc.ticker = r.ticker
    WHERE r.date >= '2022-01-03'
    AND r.ticker IN ('AAPL', 'AMZN', 'GOOGL', 'MSFT', 'TSLA', 'SPY')
),
spy AS (
    SELECT date, indexed_price AS spy_indexed
    FROM indexed
    WHERE ticker = 'SPY'
)
SELECT
    i.date, i.ticker, i.close,
    i.indexed_price,
    s.spy_indexed,
    ROUND(i.indexed_price - s.spy_indexed, 4)  AS vs_spy_absolute,
    ROUND(i.indexed_price - 100, 2)            AS total_return_pct,
    ROUND(s.spy_indexed - 100, 2)              AS spy_total_return_pct,
    CASE
        WHEN i.indexed_price > s.spy_indexed THEN 'OUTPERFORMING'
        WHEN i.indexed_price < s.spy_indexed THEN 'UNDERPERFORMING'
        ELSE 'IN LINE'
    END AS vs_spy_status
FROM indexed i
JOIN spy s ON s.date = i.date
WHERE i.ticker != 'SPY'
ORDER BY i.ticker, i.date;

-- ── VIEW 2: ASX ETFs vs A200 ──────────────────────────────────
CREATE OR REPLACE VIEW stock_analytics.analytics.v_asx_benchmark_comparison AS
WITH base_prices AS (
    SELECT ticker, MIN(date) AS base_date
    FROM stock_analytics.staging.stg_stock_prices
    WHERE date >= '2022-01-04'
    AND ticker IN ('A200.AX', 'ASIA.AX', 'CRYP.AX', 'HACK.AX', 'NDQ.AX', 'VAS.AX', 'VGS.AX')
    GROUP BY ticker
),
first_close AS (
    SELECT r.ticker, r.close AS base_price, bp.base_date
    FROM stock_analytics.staging.stg_stock_prices r
    JOIN base_prices bp ON bp.ticker = r.ticker AND bp.base_date = r.date
),
indexed AS (
    SELECT
        r.date, r.ticker, r.close, fc.base_price,
        ROUND((r.close / NULLIF(fc.base_price, 0)) * 100, 4) AS indexed_price
    FROM stock_analytics.staging.stg_stock_prices r
    JOIN first_close fc ON fc.ticker = r.ticker
    WHERE r.date >= '2022-01-04'
    AND r.ticker IN ('A200.AX', 'ASIA.AX', 'CRYP.AX', 'HACK.AX', 'NDQ.AX', 'VAS.AX', 'VGS.AX')
),
a200 AS (
    SELECT date, indexed_price AS a200_indexed
    FROM indexed
    WHERE ticker = 'A200.AX'
)
SELECT
    i.date, i.ticker, i.close,
    i.indexed_price,
    a.a200_indexed,
    ROUND(i.indexed_price - a.a200_indexed, 4)  AS vs_a200_absolute,
    ROUND(i.indexed_price - 100, 2)             AS total_return_pct,
    ROUND(a.a200_indexed - 100, 2)              AS a200_total_return_pct,
    CASE
        WHEN i.indexed_price > a.a200_indexed THEN 'OUTPERFORMING'
        WHEN i.indexed_price < a.a200_indexed THEN 'UNDERPERFORMING'
        ELSE 'IN LINE'
    END AS vs_a200_status
FROM indexed i
JOIN a200 a ON a.date = i.date
WHERE i.ticker != 'A200.AX'
ORDER BY i.ticker, i.date;

-- ── Verify both views ─────────────────────────────────────────
SELECT 'US' AS market, ticker, COUNT(*) AS row_count
FROM stock_analytics.analytics.v_benchmark_comparison
GROUP BY ticker

UNION ALL

SELECT 'ASX' AS market, ticker, COUNT(*) AS row_count
FROM stock_analytics.analytics.v_asx_benchmark_comparison
GROUP BY ticker

ORDER BY market, ticker;

-- ── VIEW 3: Global comparison — all tickers indexed to 100 ───
CREATE OR REPLACE VIEW stock_analytics.analytics.v_global_comparison AS
WITH all_tickers AS (
    SELECT ticker, MIN(date) AS base_date
    FROM stock_analytics.staging.stg_stock_prices
    WHERE ticker IN (
        'AAPL','AMZN','GOOGL','MSFT','TSLA',
        'A200.AX','ASIA.AX','CRYP.AX','HACK.AX','NDQ.AX','VAS.AX','VGS.AX'
    )
    GROUP BY ticker
),
first_close AS (
    SELECT s.ticker, s.close AS base_price, t.base_date
    FROM stock_analytics.staging.stg_stock_prices s
    JOIN all_tickers t ON t.ticker = s.ticker AND t.base_date = s.date
)
SELECT
    s.date,
    s.ticker,
    s.close,
    CASE
        WHEN s.ticker LIKE '%.AX' THEN 'ASX'
        ELSE 'US'
    END AS market,
    ROUND((s.close / NULLIF(fc.base_price, 0)) * 100, 4) AS indexed_price
FROM stock_analytics.staging.stg_stock_prices s
JOIN first_close fc ON fc.ticker = s.ticker
WHERE s.ticker IN (
    'AAPL','AMZN','GOOGL','MSFT','TSLA',
    'A200.AX','ASIA.AX','CRYP.AX','HACK.AX','NDQ.AX','VAS.AX','VGS.AX'
)
ORDER BY s.ticker, s.date;

-- Verify
SELECT ticker, market, COUNT(*) AS row_count
FROM stock_analytics.analytics.v_global_comparison
GROUP BY ticker, market
ORDER BY market, ticker;