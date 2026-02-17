#!/bin/bash
set -e

# Script to create Kubernetes secrets from OpenBao for Helm deployment
# Usage: ./scripts/create-secrets-from-openbao.sh

NAMESPACE="${1:-eleduck-analytics}"

echo "🔐 Creating Kubernetes secrets from OpenBao for namespace: ${NAMESPACE}"
echo ""

# Check if namespace exists, create if not
if ! kubectl get namespace ${NAMESPACE} &> /dev/null; then
    echo "📦 Creating namespace ${NAMESPACE}..."
    kubectl create namespace ${NAMESPACE}
fi

# Check OpenBao connection
if [ -z "$OPENBAO_ADDR" ]; then
    echo "❌ OPENBAO_ADDR not set. Please set it first:"
    echo "   export OPENBAO_ADDR=http://localhost:8200"
    exit 1
fi

echo "✅ OpenBao address: $OPENBAO_ADDR"
echo ""

# Function to get secret from OpenBao
get_secret() {
    local path=$1
    local key=$2
    vault kv get -field=${key} ${path} 2>/dev/null || echo ""
}

echo "1️⃣  Creating supabase-credentials secret (direct connection)..."
DB_USERNAME=$(get_secret secret/eleduck-analytics/database-direct username)
DB_PASSWORD=$(get_secret secret/eleduck-analytics/database-direct password)
DB_HOST=$(get_secret secret/eleduck-analytics/database-direct host)
DB_PORT=$(get_secret secret/eleduck-analytics/database-direct port)
DB_NAME=$(get_secret secret/eleduck-analytics/database-direct dbname)

if [ -z "$DB_USERNAME" ] || [ -z "$DB_PASSWORD" ]; then
    echo "❌ Failed to get database credentials from OpenBao"
    exit 1
fi

kubectl create secret generic supabase-credentials \
    --from-literal=DATABASE_USER="${DB_USERNAME}" \
    --from-literal=DATABASE_PASSWORD="${DB_PASSWORD}" \
    --from-literal=DATABASE_HOST="${DB_HOST}" \
    --from-literal=DATABASE_PORT="${DB_PORT}" \
    --from-literal=DATABASE_NAME="${DB_NAME}" \
    --namespace=${NAMESPACE} \
    --dry-run=client -o yaml | kubectl apply -f -

echo "✅ supabase-credentials created (using direct connection)"
echo ""

echo "2️⃣  Creating motherduck-credentials secret..."
MD_TOKEN=$(get_secret secret/eleduck-analytics/motherduck token)

if [ -z "$MD_TOKEN" ]; then
    echo "❌ Failed to get MotherDuck token from OpenBao"
    exit 1
fi

kubectl create secret generic motherduck-credentials \
    --from-literal=token="${MD_TOKEN}" \
    --namespace=${NAMESPACE} \
    --dry-run=client -o yaml | kubectl apply -f -

echo "✅ motherduck-credentials created"
echo ""

echo "3️⃣  Creating podcast-scraper-credentials secret..."
APPLE_EMAIL=$(get_secret secret/eleduck-analytics/podcast-scraper apple_email)
APPLE_PASSWORD=$(get_secret secret/eleduck-analytics/podcast-scraper apple_password)
SPOTIFY_COOKIE=$(get_secret secret/eleduck-analytics/podcast-scraper spotify_sp_cookie)
SPOTIFY_KEY=$(get_secret secret/eleduck-analytics/podcast-scraper spotify_sp_key_cookie)
AMAZON_COOKIE=$(get_secret secret/eleduck-analytics/podcast-scraper amazon_session_cookie)
YOUTUBE_KEY=$(get_secret secret/eleduck-analytics/podcast-scraper youtube_api_key)
YOUTUBE_TOKEN=$(get_secret secret/eleduck-analytics/podcast-scraper youtube_access_token)

kubectl create secret generic podcast-scraper-credentials \
    --from-literal=apple_email="${APPLE_EMAIL}" \
    --from-literal=apple_password="${APPLE_PASSWORD}" \
    --from-literal=spotify_sp_cookie="${SPOTIFY_COOKIE}" \
    --from-literal=spotify_sp_key_cookie="${SPOTIFY_KEY}" \
    --from-literal=amazon_session_cookie="${AMAZON_COOKIE}" \
    --from-literal=youtube_api_key="${YOUTUBE_KEY}" \
    --from-literal=youtube_access_token="${YOUTUBE_TOKEN}" \
    --namespace=${NAMESPACE} \
    --dry-run=client -o yaml | kubectl apply -f -

echo "✅ podcast-scraper-credentials created"
echo ""

echo "🎉 All secrets created successfully!"
echo ""
echo "Next step:"
echo "  helm upgrade --install eleduck-analytics ./helm/eleduck-analytics \\"
echo "    -n ${NAMESPACE} \\"
echo "    -f ./helm/eleduck-analytics/values-zot.yaml"
echo ""
