-- ============================================================
-- FILE: 01_setup.sql
-- PURPOSE: Create database, schemas, and warehouse
-- Run this first before anything else
-- ============================================================

-- Create a dedicated database for the project
CREATE DATABASE IF NOT EXISTS stock_analytics;

-- Create schemas to separate concerns
CREATE SCHEMA IF NOT EXISTS stock_analytics.raw;        -- raw ingested data
CREATE SCHEMA IF NOT EXISTS stock_analytics.staging;    -- cleaned/transformed
CREATE SCHEMA IF NOT EXISTS stock_analytics.analytics;  -- final reporting layer

-- Create a virtual warehouse (compute engine)
CREATE WAREHOUSE IF NOT EXISTS stock_wh
  WAREHOUSE_SIZE = 'X-SMALL'
  AUTO_SUSPEND = 60        -- suspends after 60s of inactivity (saves credits)
  AUTO_RESUME = TRUE;

-- Set context
USE DATABASE stock_analytics;
USE SCHEMA raw;
USE WAREHOUSE stock_wh;
