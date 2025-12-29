# Metabase Deployment - Next Steps

## Pre-Deployment

1. **Create 1Password Item**
   - Vault: `SoypeteTech`
   - Item name: `eleduck-metabase`
   - Fields:
     - `admin_email`: your-admin@email.com
     - `admin_password`: (generate secure password, for reference only)

2. **Ensure Prerequisites are Running**
   ```bash
   # Verify PostgreSQL is running
   kubectl get pods -n eleduck-analytics -l app=postgres

   # Verify metabase_app database exists
   make psql
   \l  # List databases, should see metabase_app
   ```

## Deployment

```bash
# Deploy full stack (includes Metabase)
make deploy

# Or deploy just Metabase
kubectl apply -k k8s/metabase/

# Wait for pod to be ready
kubectl wait --for=condition=ready pod -l app=metabase -n eleduck-analytics --timeout=300s
```

## Initial Setup

1. **Access Metabase**
   ```bash
   make port-forward-metabase
   # Open http://localhost:3000
   ```

2. **Create Admin Account**
   - Use email from 1Password item
   - Set a secure password

3. **Add Analytics Database**
   - Click "Add a database"
   - Database type: **PostgreSQL**
   - Host: `postgres.eleduck-analytics.svc.cluster.local`
   - Port: `5432`
   - Database name: `analytics`
   - Username: (from postgres-credentials secret)
   - Password: (from postgres-credentials secret)
   - Schema filter: `analytics`

4. **Verify Connection**
   - Browse the database
   - Confirm dimension and fact tables are visible

## Create Starter Dashboards

Suggested dashboards to create:

### Content Overview
- Total views by platform (last 30 days)
- Top 10 content by engagement
- Views trend over time
- Platform comparison pie chart

### Revenue Dashboard
- Monthly revenue trend
- Revenue by product
- Customer count over time
- Average transaction value

### GitHub Activity
- Commits per week by repository
- PR merge rate
- Issue resolution time
- Contributor activity

## Troubleshooting

```bash
# Check logs
make logs-metabase

# Restart if needed
make restart-metabase

# Shell access
make metabase-shell
```

## Create Pull Request

```bash
gh pr create --title "feat: add Metabase deployment for analytics visualization" --body "$(cat <<'EOF'
## Summary
Adds Metabase deployment for analytics visualization and dashboards.

## Components
- Metabase deployment with PostgreSQL backend
- ClusterIP service (Tailscale access)
- Persistent storage for Metabase data
- Documentation for setup and usage

## Features
- Connects to analytics schema (star schema)
- Supports pg_duckdb for heavy queries
- Dashboard export/import for version control

## Prerequisites
- Plans 1-3 deployed
- DBT has run and populated analytics schema

## Deployment
\`\`\`bash
kubectl apply -k k8s/metabase/
make port-forward-metabase
# Complete setup at http://localhost:3000
\`\`\`

## Initial Setup
1. Create admin account
2. Add PostgreSQL database:
   - Host: postgres.eleduck-analytics.svc.cluster.local
   - Database: analytics
   - Schema: analytics
EOF
)"
```
