#!/bin/bash
set -e

# Script to initialize MotherDuck database and schemas
# Usage: ./scripts/motherduck-init.sh

echo "🦆 Initializing MotherDuck for Eleduck Analytics..."
echo ""

# Get MotherDuck token from 1Password
echo "🔐 Fetching credentials from 1Password..."
MOTHERDUCK_TOKEN=$(op read "op://pedro/MotherDuck_access/credential")

if [ -z "$MOTHERDUCK_TOKEN" ]; then
    echo "❌ Failed to get MotherDuck token from 1Password"
    exit 1
fi

echo "✅ Token loaded"
echo ""

# Install duckdb CLI if not present
if ! command -v duckdb &> /dev/null; then
    echo "📦 Installing DuckDB CLI..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        brew install duckdb
    else
        echo "❌ Please install DuckDB CLI: https://duckdb.org/docs/installation/"
        exit 1
    fi
fi

echo "🔌 Connecting to MotherDuck..."
echo ""

# Create a temporary SQL file with the initialization commands
cat > /tmp/motherduck_init.sql << EOF
-- Connect to MotherDuck and create/use the eleduck_analytics database
CREATE DATABASE IF NOT EXISTS eleduck_analytics;
USE eleduck_analytics;

-- Create schemas
CREATE SCHEMA IF NOT EXISTS raw;
CREATE SCHEMA IF NOT EXISTS staging;
CREATE SCHEMA IF NOT EXISTS analytics;

-- Show what we created
SHOW DATABASES;
SELECT schema_name FROM information_schema.schemata WHERE schema_name IN ('raw', 'staging', 'analytics');
EOF

echo "📐 Creating database and schemas..."
echo ""

# Run the SQL commands against MotherDuck
duckdb "md:?motherduck_token=${MOTHERDUCK_TOKEN}" < /tmp/motherduck_init.sql

# Clean up
rm /tmp/motherduck_init.sql

echo ""
echo "🎉 MotherDuck initialization complete!"
echo ""
echo "Database: eleduck_analytics"
echo "Schemas: raw, staging, analytics"
echo ""
echo "Next steps:"
echo "  1. Store token in OpenBao: bao kv put secret/eleduck-analytics/motherduck token=\$MOTHERDUCK_TOKEN"
echo "  2. Deploy via Foundry: cd ../pedro-ops && foundryctl stack apply stack.yml"
echo ""
