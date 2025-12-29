-- Initialize database schemas for eleduck-analytics
-- This script is also embedded in the ConfigMap but kept here for reference

-- Create schemas for data warehouse layers
CREATE SCHEMA IF NOT EXISTS raw;
CREATE SCHEMA IF NOT EXISTS staging;
CREATE SCHEMA IF NOT EXISTS analytics;

-- Grant usage to the main user
GRANT ALL ON SCHEMA raw TO CURRENT_USER;
GRANT ALL ON SCHEMA staging TO CURRENT_USER;
GRANT ALL ON SCHEMA analytics TO CURRENT_USER;

-- Set default search path
ALTER DATABASE analytics SET search_path TO analytics, staging, raw, public;
