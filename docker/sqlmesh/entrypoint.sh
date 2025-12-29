#!/bin/bash
set -e

# Export environment variables for SQLMesh config
export POSTGRES_HOST="${POSTGRES_HOST:-postgres.eleduck-analytics.svc.cluster.local}"
export POSTGRES_PORT="${POSTGRES_PORT:-5432}"
export POSTGRES_USER="${POSTGRES_USER}"
export POSTGRES_PASSWORD="${POSTGRES_PASSWORD}"
export POSTGRES_DB="${POSTGRES_DB:-analytics}"

# Run SQLMesh command
case "$1" in
    plan)
        shift
        sqlmesh --gateway prod plan "$@"
        ;;
    run)
        shift
        sqlmesh --gateway prod run "$@"
        ;;
    audit)
        shift
        sqlmesh --gateway prod audit "$@"
        ;;
    test)
        shift
        sqlmesh --gateway prod test "$@"
        ;;
    *)
        sqlmesh --gateway prod "$@"
        ;;
esac
