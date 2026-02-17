#!/bin/bash
set -e

# Script to connect to Supabase using credentials from 1Password
# Usage: ./scripts/supabase-connect.sh [database_name]

echo "🔐 Fetching Supabase credentials from 1Password..."

# Get connection credentials from 1Password
CREDS=$(op item get "POSTGRES_URL" --vault pedro --reveal --fields credential)
BASE_URL="postgresql://$(echo "$CREDS" | grep -o 'user=[^ ]*' | cut -d= -f2):$(echo "$CREDS" | grep -o 'password=[^ ]*' | cut -d= -f2)@$(echo "$CREDS" | grep -o 'host=[^ ]*' | cut -d= -f2):$(echo "$CREDS" | grep -o 'port=[^ ]*' | cut -d= -f2)"

# Use provided database name or default to postgres
DATABASE=${1:-postgres}

# Build connection string
CONNECTION_URL="${BASE_URL}/${DATABASE}"

echo "✅ Credentials loaded"
echo "📍 Database: ${DATABASE}"
echo ""
echo "🔌 Connecting to Supabase..."
psql "$CONNECTION_URL"
