-- Runs once on first container start (empty data volume).
-- Operational source + staging + analytics schemas for Phase A.

CREATE SCHEMA IF NOT EXISTS ops;
CREATE SCHEMA IF NOT EXISTS staging;
CREATE SCHEMA IF NOT EXISTS analytics;

COMMENT ON SCHEMA ops IS 'Operational source tables loaded from Olist CSVs';
COMMENT ON SCHEMA staging IS 'ETL staging area (truncate/reload safe)';
COMMENT ON SCHEMA analytics IS 'Curated / warehouse tables for reporting';
