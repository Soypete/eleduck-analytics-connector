-- Enable pg_duckdb extension for analytical queries
CREATE EXTENSION IF NOT EXISTS pg_duckdb;

-- To use DuckDB execution mode for a session:
-- SET duckdb.execution = true;

-- To use DuckDB for a single query, wrap it:
-- SELECT * FROM duckdb.query('SELECT ...');

-- Check if extension is loaded
SELECT * FROM pg_extension WHERE extname = 'pg_duckdb';
