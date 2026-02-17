#!/bin/bash
set -e

# Script to initialize Supabase databases and schemas
# Usage: ./scripts/supabase-init.sh

echo "🚀 Initializing Supabase for Eleduck Analytics..."
echo ""

# Get connection credentials from 1Password
echo "🔐 Fetching credentials from 1Password..."
CREDS=$(op item get "POSTGRES_URL" --vault pedro --reveal --fields credential)
BASE_URL="postgresql://$(echo "$CREDS" | grep -o 'user=[^ ]*' | cut -d= -f2):$(echo "$CREDS" | grep -o 'password=[^ ]*' | cut -d= -f2)@$(echo "$CREDS" | grep -o 'host=[^ ]*' | cut -d= -f2):$(echo "$CREDS" | grep -o 'port=[^ ]*' | cut -d= -f2)/postgres"

echo "✅ Credentials loaded"
echo ""

# Function to run SQL
run_sql() {
    local db=$1
    local sql=$2
    echo "  Running: $sql"
    local url="${BASE_URL%/*}/${db}"
    psql "$url" -c "$sql"
}

# 1. Create databases
echo "📦 Creating databases..."
run_sql "postgres" "CREATE DATABASE airbyte_internal;" 2>&1 | grep -v "already exists" || echo "  ℹ️  airbyte_internal already exists"
run_sql "postgres" "CREATE DATABASE metabase_app;" 2>&1 | grep -v "already exists" || echo "  ℹ️  metabase_app already exists"
run_sql "postgres" "CREATE DATABASE analytics;" 2>&1 | grep -v "already exists" || echo "  ℹ️  analytics already exists"
echo ""

# 2. Create schemas in analytics database
echo "📐 Creating schemas in analytics database..."
run_sql "analytics" "CREATE SCHEMA IF NOT EXISTS raw;"
run_sql "analytics" "CREATE SCHEMA IF NOT EXISTS staging;"
run_sql "analytics" "CREATE SCHEMA IF NOT EXISTS analytics;"
echo ""

# 3. Run initialization SQL if exists
if [ -f "scripts/init-schemas.sql" ]; then
    echo "📄 Running init-schemas.sql..."
    ANALYTICS_URL="${BASE_URL%/*}/analytics"
    psql "$ANALYTICS_URL" -f scripts/init-schemas.sql
    echo ""
fi

# 4. Verify setup
echo "✅ Verification:"
echo ""
echo "Databases:"
run_sql "postgres" "SELECT datname FROM pg_database WHERE datname IN ('airbyte_internal', 'metabase_app', 'analytics');"
echo ""
echo "Schemas in analytics:"
run_sql "analytics" "SELECT schema_name FROM information_schema.schemata WHERE schema_name IN ('raw', 'staging', 'analytics');"
echo ""

echo "🎉 Supabase initialization complete!"
echo ""
echo "Next steps:"
echo "  1. Store credentials in OpenBao: ./scripts/sync-secrets-to-openbao.sh"
echo "  2. Deploy via Foundry: cd ../pedro-ops && foundryctl stack apply stack.yml"
echo "  3. Or test connection: ./scripts/supabase-connect.sh analytics"
