-- ============================================================
-- FILE: 02_raw.sql
-- PURPOSE: Create stage, temp table, and raw_stock_prices table
-- Ingests stock data from CSV uploaded to Snowflake stage
-- ============================================================

USE SCHEMA stock_analytics.raw;
USE WAREHOUSE stock_wh;

-- ------------------------------------------------------------
-- STEP 1: Create internal stage (CSV landing zone)
-- ------------------------------------------------------------
CREATE STAGE IF NOT EXISTS stock_analytics.raw.stock_stage
  FILE_FORMAT = (TYPE = 'CSV' FIELD_OPTIONALLY_ENCLOSED_BY = '"' SKIP_HEADER = 1);

-- Upload your CSV via Snowsight:
-- Data > Databases > stock_analytics > raw > Stages > stock_stage > Upload Files

-- ------------------------------------------------------------
-- STEP 2: Create temp table to hold wide CSV format (27 columns)
-- yfinance outputs one set of OHLCV columns per ticker
-- ------------------------------------------------------------
CREATE OR REPLACE TABLE stock_analytics.raw.raw_stage_temp (
    c1 VARCHAR, c2 VARCHAR, c3 VARCHAR, c4 VARCHAR, c5 VARCHAR,
    c6 VARCHAR, c7 VARCHAR, c8 VARCHAR, c9 VARCHAR, c10 VARCHAR,
    c11 VARCHAR, c12 VARCHAR, c13 VARCHAR, c14 VARCHAR, c15 VARCHAR,
    c16 VARCHAR, c17 VARCHAR, c18 VARCHAR, c19 VARCHAR, c20 VARCHAR,
    c21 VARCHAR, c22 VARCHAR, c23 VARCHAR, c24 VARCHAR, c25 VARCHAR,
    c26 VARCHAR, c27 VARCHAR
);

-- ------------------------------------------------------------
-- STEP 3: Load CSV into temp table (skip 2 header rows)
-- ------------------------------------------------------------
COPY INTO stock_analytics.raw.raw_stage_temp
FROM @stock_analytics.raw.stock_stage/stock_prices_raw.csv
FILE_FORMAT = (TYPE = 'CSV' SKIP_HEADER = 2);

-- ------------------------------------------------------------
-- STEP 4: Create final raw table with proper structure
-- ------------------------------------------------------------
CREATE OR REPLACE TABLE stock_analytics.raw.raw_stock_prices (
    date        DATE,
    close       FLOAT,
    high        FLOAT,
    low         FLOAT,
    open        FLOAT,
    volume      FLOAT,
    ticker      VARCHAR,
    loaded_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP  -- audit column
);

-- ------------------------------------------------------------
-- STEP 5: Unpivot wide format into long format (one row per ticker per day)
-- Column mapping: AAPL(c2-c6), AMZN(c8-c12), GOOGL(c14-c18), MSFT(c20-c24), TSLA(c26-c27)
-- ------------------------------------------------------------
INSERT INTO stock_analytics.raw.raw_stock_prices (date, close, high, low, open, volume, ticker)
SELECT TRY_TO_DATE(c1), TRY_TO_DOUBLE(c2), TRY_TO_DOUBLE(c3), TRY_TO_DOUBLE(c4), TRY_TO_DOUBLE(c5), TRY_TO_DOUBLE(c6), 'AAPL' FROM stock_analytics.raw.raw_stage_temp
UNION ALL
SELECT TRY_TO_DATE(c1), TRY_TO_DOUBLE(c8), TRY_TO_DOUBLE(c9), TRY_TO_DOUBLE(c10), TRY_TO_DOUBLE(c11), TRY_TO_DOUBLE(c12), 'AMZN' FROM stock_analytics.raw.raw_stage_temp
UNION ALL
SELECT TRY_TO_DATE(c1), TRY_TO_DOUBLE(c14), TRY_TO_DOUBLE(c15), TRY_TO_DOUBLE(c16), TRY_TO_DOUBLE(c17), TRY_TO_DOUBLE(c18), 'GOOGL' FROM stock_analytics.raw.raw_stage_temp
UNION ALL
SELECT TRY_TO_DATE(c1), TRY_TO_DOUBLE(c20), TRY_TO_DOUBLE(c21), TRY_TO_DOUBLE(c22), TRY_TO_DOUBLE(c23), TRY_TO_DOUBLE(c24), 'MSFT' FROM stock_analytics.raw.raw_stage_temp
UNION ALL
SELECT TRY_TO_DATE(c1), TRY_TO_DOUBLE(c26), TRY_TO_DOUBLE(c27), NULL, NULL, NULL, 'TSLA' FROM stock_analytics.raw.raw_stage_temp;

-- ------------------------------------------------------------
-- STEP 6: Verify load
-- ------------------------------------------------------------
SELECT ticker, COUNT(*) AS row_count
FROM stock_analytics.raw.raw_stock_prices
WHERE date IS NOT NULL
GROUP BY ticker
ORDER BY ticker;
