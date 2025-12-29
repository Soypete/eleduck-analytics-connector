#!/bin/bash
set -e

# Write profiles.yml from environment
cat > /dbt/profiles.yml << EOF
eleduck_analytics:
  target: prod
  outputs:
    prod:
      type: postgres
      host: ${POSTGRES_HOST:-postgres.eleduck-analytics.svc.cluster.local}
      port: ${POSTGRES_PORT:-5432}
      user: ${POSTGRES_USER}
      password: ${POSTGRES_PASSWORD}
      dbname: ${POSTGRES_DB:-analytics}
      schema: analytics
      threads: 4
EOF

# Run DBT command
case "$1" in
    build)
        dbt build --target prod
        ;;
    run)
        dbt run --target prod
        ;;
    test)
        dbt test --target prod
        ;;
    seed)
        dbt seed --target prod
        ;;
    *)
        dbt "$@"
        ;;
esac
