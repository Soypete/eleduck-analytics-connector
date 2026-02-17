#!/bin/bash
set -e

# Script to build and push container images to Zot registry
# Usage: ./scripts/build-and-push.sh [registry]

REGISTRY="${1:-100.81.89.62:5000}"
NAMESPACE="eleduck"

echo "🏗️  Building and pushing images to ${REGISTRY}/${NAMESPACE}"
echo ""

# Function to build and push
build_and_push() {
    local name=$1
    local dockerfile=$2
    local context=${3:-.}

    local image="${REGISTRY}/${NAMESPACE}/${name}:latest"

    echo "📦 Building ${name}..."
    podman build -t "$image" -f "$dockerfile" "$context"

    echo "⬆️  Pushing ${name}..."
    podman push --tls-verify=false "$image"

    echo "✅ ${image}"
    echo ""
}

# Build all images
echo "Starting builds..."
echo ""

# 1. SQLMesh
build_and_push "sqlmesh" "docker/sqlmesh/Dockerfile" "."

# 2. Podcast Scraper
build_and_push "podcast-scraper" "docker/podcast-scraper/Dockerfile" "."

echo "🎉 All images built and pushed!"
echo ""
echo "Images available at:"
echo "  - ${REGISTRY}/${NAMESPACE}/sqlmesh:latest"
echo "  - ${REGISTRY}/${NAMESPACE}/podcast-scraper:latest"
echo ""
echo "Next: Update helm/eleduck-analytics/values-foundry.yaml to use these images"
