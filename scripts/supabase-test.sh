#!/bin/bash
set -e

# Quick test script for Supabase connectivity
# Usage: ./scripts/supabase-test.sh

echo "🧪 Testing Supabase connection..."

# Get connection credentials from 1Password and convert to URL
CREDS=$(op item get "POSTGRES_URL" --vault pedro --reveal --fields credential)
CONNECTION_URL="postgresql://$(echo "$CREDS" | grep -o 'user=[^ ]*' | cut -d= -f2):$(echo "$CREDS" | grep -o 'password=[^ ]*' | cut -d= -f2)@$(echo "$CREDS" | grep -o 'host=[^ ]*' | cut -d= -f2):$(echo "$CREDS" | grep -o 'port=[^ ]*' | cut -d= -f2)/$(echo "$CREDS" | grep -o 'dbname=[^ ]*' | cut -d= -f2)"

echo "📍 Testing connection..."
echo ""

# Run test query
psql "$CONNECTION_URL" -c "SELECT version();" && echo "" && echo "✅ Connection successful!"

# Check databases exist
echo ""
echo "📊 Checking databases..."
psql "$CONNECTION_URL" -c "SELECT datname FROM pg_database WHERE datname IN ('airbyte_internal', 'metabase_app', 'analytics');"

# Check analytics schemas
echo ""
echo "📐 Checking analytics schemas..."
ANALYTICS_URL="${CONNECTION_URL%/*}/analytics"
psql "$ANALYTICS_URL" -c "SELECT schema_name FROM information_schema.schemata WHERE schema_name IN ('raw', 'staging', 'analytics');" 2>/dev/null || echo "⚠️  Analytics database or schemas not found"

echo ""
echo "🎉 Tests complete!"
