USE SCHEMA stock_analytics.analytics;
USE WAREHOUSE stock_wh;

-- VIEW 1: Overall stock performance summary
CREATE OR REPLACE VIEW stock_analytics.analytics.v_stock_performance AS
SELECT
    ticker,
    ROUND(MIN(close), 2)              AS lowest_price,
    ROUND(MAX(close), 2)              AS highest_price,
    ROUND(MAX(close) - MIN(close), 2) AS price_range,
    MAX(daily_return_pct)             AS best_single_day,
    MIN(daily_return_pct)             AS worst_single_day,
    ROUND(AVG(daily_return_pct), 4)   AS avg_daily_return,
    ROUND(AVG(volatility_30day), 4)   AS avg_volatility,
    SUM(volume)                       AS total_volume
FROM stock_analytics.analytics.fact_daily_returns
WHERE daily_return_pct IS NOT NULL
GROUP BY ticker
ORDER BY avg_daily_return DESC;

-- VIEW 2: Monthly returns
CREATE OR REPLACE VIEW stock_analytics.analytics.v_monthly_returns AS
SELECT
    ticker,
    DATE_TRUNC('month', date)                                            AS month,
    ROUND(MIN(close), 2)                                                 AS month_low,
    ROUND(MAX(close), 2)                                                 AS month_high,
    ROUND(AVG(close), 2)                                                 AS avg_close,
    SUM(volume)                                                          AS monthly_volume,
    ROUND(((MAX(close) - MIN(close)) / NULLIF(MIN(close), 0)) * 100, 2) AS monthly_return_pct
FROM stock_analytics.analytics.fact_daily_returns
GROUP BY ticker, DATE_TRUNC('month', date)
ORDER BY ticker, month;

-- VIEW 3: MA crossover signals
CREATE OR REPLACE VIEW stock_analytics.analytics.v_ma_crossover AS
SELECT
    date, ticker, close, ma_7day, ma_30day,
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

-- VIEW 4: Yearly summary
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

-- VIEW 5: Drawdown
CREATE OR REPLACE VIEW stock_analytics.analytics.v_drawdown AS
WITH running_max AS (
    SELECT date, ticker, close,
        MAX(close) OVER (
            PARTITION BY ticker ORDER BY date
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS peak_price
    FROM stock_analytics.analytics.fact_daily_returns
)
SELECT
    date, ticker, close, peak_price,
    ROUND(close - peak_price, 2)                                        AS drawdown_amount,
    ROUND(((close - peak_price) / NULLIF(peak_price, 0)) * 100, 2)     AS drawdown_pct,
    CASE
        WHEN ((close - peak_price) / NULLIF(peak_price, 0)) * 100 >= -5  THEN 'HEALTHY'
        WHEN ((close - peak_price) / NULLIF(peak_price, 0)) * 100 >= -15 THEN 'MODERATE'
        WHEN ((close - peak_price) / NULLIF(peak_price, 0)) * 100 >= -30 THEN 'SIGNIFICANT'
        ELSE 'SEVERE'
    END AS drawdown_status
FROM running_max;

-- VIEW 6: Risk metrics
CREATE OR REPLACE VIEW stock_analytics.analytics.v_risk_metrics AS
WITH daily AS (
    SELECT ticker, date, daily_return_pct, volatility_30day
    FROM stock_analytics.analytics.fact_daily_returns
    WHERE daily_return_pct IS NOT NULL
),
per_ticker AS (
    SELECT
        ticker,
        MIN(daily_return_pct)                          AS worst_day,
        MAX(daily_return_pct)                          AS best_day,
        ROUND(AVG(daily_return_pct), 4)                AS avg_daily_return,
        ROUND(STDDEV(daily_return_pct), 4)             AS daily_volatility,
        ROUND(STDDEV(daily_return_pct) * SQRT(252), 4) AS annualised_volatility,
        ROUND(PERCENTILE_CONT(0.05) WITHIN GROUP
            (ORDER BY daily_return_pct), 4)            AS var_95,
        COUNT(*)                                       AS trading_days
    FROM daily
    GROUP BY ticker
)
SELECT
    ticker, worst_day, best_day, avg_daily_return,
    daily_volatility, annualised_volatility, var_95,
    ROUND((avg_daily_return - (4.0/252)) / NULLIF(daily_volatility, 0), 4) AS sharpe_ratio,
    ROUND(avg_daily_return / NULLIF(
        (SELECT STDDEV(dr.daily_return_pct)
         FROM daily dr
         WHERE dr.ticker = per_ticker.ticker
         AND dr.daily_return_pct < 0), 0), 4) AS sortino_ratio,
    trading_days
FROM per_ticker;

-- VIEW 7: Rolling volatility
CREATE OR REPLACE VIEW stock_analytics.analytics.v_rolling_volatility AS
SELECT
    date, ticker, close, volatility_30day,
    ROUND(STDDEV(daily_return_pct) OVER (
        PARTITION BY ticker ORDER BY date ROWS BETWEEN 19 PRECEDING AND CURRENT ROW
    ), 4) AS volatility_20day,
    ROUND(STDDEV(daily_return_pct) OVER (
        PARTITION BY ticker ORDER BY date ROWS BETWEEN 59 PRECEDING AND CURRENT ROW
    ), 4) AS volatility_60day,
    CASE
        WHEN volatility_30day > 3   THEN 'HIGH'
        WHEN volatility_30day > 1.5 THEN 'MEDIUM'
        ELSE 'LOW'
    END AS volatility_regime
FROM stock_analytics.analytics.fact_daily_returns
WHERE daily_return_pct IS NOT NULL;

-- VIEW 8: Momentum indicators
CREATE OR REPLACE VIEW stock_analytics.analytics.v_momentum_indicators AS
WITH rsi_calc AS (
    SELECT date, ticker, close, daily_return_pct,
        CASE WHEN daily_return_pct > 0 THEN daily_return_pct ELSE 0 END AS gain,
        CASE WHEN daily_return_pct < 0 THEN ABS(daily_return_pct) ELSE 0 END AS loss
    FROM stock_analytics.analytics.fact_daily_returns
    WHERE daily_return_pct IS NOT NULL
),
rsi_avg AS (
    SELECT date, ticker, close, daily_return_pct,
        AVG(gain) OVER (PARTITION BY ticker ORDER BY date ROWS BETWEEN 13 PRECEDING AND CURRENT ROW) AS avg_gain_14,
        AVG(loss) OVER (PARTITION BY ticker ORDER BY date ROWS BETWEEN 13 PRECEDING AND CURRENT ROW) AS avg_loss_14
    FROM rsi_calc
),
price_52wk AS (
    SELECT date, ticker, close, daily_return_pct, avg_gain_14, avg_loss_14,
        MAX(close) OVER (PARTITION BY ticker ORDER BY date ROWS BETWEEN 251 PRECEDING AND CURRENT ROW) AS high_52wk,
        MIN(close) OVER (PARTITION BY ticker ORDER BY date ROWS BETWEEN 251 PRECEDING AND CURRENT ROW) AS low_52wk
    FROM rsi_avg
)
SELECT
    date, ticker, close, high_52wk, low_52wk,
    ROUND(((close - low_52wk)  / NULLIF(high_52wk - low_52wk, 0)) * 100, 2) AS pct_of_52wk_range,
    ROUND(((close - high_52wk) / NULLIF(high_52wk, 0)) * 100, 2)            AS pct_from_52wk_high,
    ROUND(((close - low_52wk)  / NULLIF(low_52wk,  0)) * 100, 2)            AS pct_from_52wk_low,
    ROUND(100 - (100 / (1 + NULLIF(avg_gain_14 / NULLIF(avg_loss_14, 0), 0))), 2) AS rsi_14,
    CASE
        WHEN ROUND(100 - (100 / (1 + NULLIF(avg_gain_14 / NULLIF(avg_loss_14, 0), 0))), 2) >= 70 THEN 'OVERBOUGHT'
        WHEN ROUND(100 - (100 / (1 + NULLIF(avg_gain_14 / NULLIF(avg_loss_14, 0), 0))), 2) <= 30 THEN 'OVERSOLD'
        ELSE 'NEUTRAL'
    END AS rsi_signal,
    ROUND(((close - LAG(close, 20) OVER (PARTITION BY ticker ORDER BY date))
        / NULLIF(LAG(close, 20) OVER (PARTITION BY ticker ORDER BY date), 0)) * 100, 2) AS roc_20day
FROM price_52wk;

-- VIEW 9: Volume analysis
CREATE OR REPLACE VIEW stock_analytics.analytics.v_volume_analysis AS
SELECT
    date, ticker, close, volume,
    ROUND(AVG(volume) OVER (
        PARTITION BY ticker ORDER BY date ROWS BETWEEN 19 PRECEDING AND CURRENT ROW
    ), 0) AS avg_volume_20day,
    ROUND(volume / NULLIF(AVG(volume) OVER (
        PARTITION BY ticker ORDER BY date ROWS BETWEEN 19 PRECEDING AND CURRENT ROW
    ), 0), 2) AS relative_volume,
    CASE
        WHEN volume > 2 * AVG(volume) OVER (
            PARTITION BY ticker ORDER BY date ROWS BETWEEN 19 PRECEDING AND CURRENT ROW
        ) THEN TRUE ELSE FALSE
    END AS volume_spike,
    CASE
        WHEN AVG(volume) OVER (
            PARTITION BY ticker ORDER BY date ROWS BETWEEN 4 PRECEDING AND CURRENT ROW
        ) > AVG(volume) OVER (
            PARTITION BY ticker ORDER BY date ROWS BETWEEN 19 PRECEDING AND CURRENT ROW
        ) THEN 'INCREASING'
        ELSE 'DECREASING'
    END AS volume_trend
FROM stock_analytics.analytics.fact_daily_returns;

-- Verify all views
SHOW VIEWS IN SCHEMA stock_analytics.analytics;