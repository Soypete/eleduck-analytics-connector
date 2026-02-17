# Migration Status: Kustomize to Helm + Foundry Cluster

**Date**: February 14, 2026
**Status**: Phase 1 & 2 Complete ✅

## Completed Work

### Phase 1: Prerequisites ✅

- [x] **Sealed Secrets Installed**: Controller deployed and running on Foundry cluster
- [x] **Namespace Created**: `eleduck-analytics` namespace created on Foundry cluster
- [x] **Cluster Access Verified**: Successfully connected to Foundry cluster at `https://100.118.20.111:6443`

### Phase 2: Helm Chart Creation ✅

Created complete Helm umbrella chart structure:

```
helm/eleduck-analytics/
├── Chart.yaml                    # Main chart with Airbyte 1.9.2 dependency
├── values.yaml                   # Base configuration
├── values-foundry.yaml           # Foundry cluster overrides
├── README.md                     # Comprehensive documentation
├── .helmignore
├── templates/
│   ├── _helpers.tpl
│   └── namespace.yaml
└── charts/
    ├── airbyte/                  # Downloaded from upstream (1.9.2)
    ├── metabase/                 # Custom subchart
    │   ├── Chart.yaml
    │   ├── values.yaml
    │   └── templates/
    │       ├── _helpers.tpl
    │       ├── deployment.yaml
    │       ├── service.yaml
    │       ├── pvc.yaml
    │       └── ingress.yaml
    ├── sqlmesh/                  # Custom subchart
    │   ├── Chart.yaml
    │   ├── values.yaml
    │   └── templates/
    │       ├── _helpers.tpl
    │       └── cronjob.yaml
    └── podcast-scraper/          # Custom subchart
        ├── Chart.yaml
        ├── values.yaml
        └── templates/
            ├── _helpers.tpl
            └── cronjob.yaml
```

**Chart Features:**
- ✅ Umbrella chart pattern with local and external dependencies
- ✅ Parameterized templates using Helm best practices
- ✅ Separate base and environment-specific values files
- ✅ Support for Supabase external database
- ✅ Contour ingress configuration with Tailscale DNS
- ✅ Longhorn storage class support
- ✅ Monitoring annotations (Prometheus ServiceMonitor ready)
- ✅ Resource limits and requests defined
- ✅ Liveness and readiness probes
- ✅ Comprehensive README with troubleshooting guide

### Phase 4: GitHub Actions CI/CD ✅

Created two GitHub Actions workflows:

#### 1. `.github/workflows/deploy.yaml`
- Triggers on push to main when `helm/**` changes
- Deploys Helm chart to Foundry cluster
- Uses `KUBE_CONFIG` secret for cluster access
- Includes validation and health checks

#### 2. `.github/workflows/build-images.yaml`
- Builds three container images: `postgres-duckdb`, `eleduck-sqlmesh`, `podcast-scraper`
- Path-based change detection (only rebuilds changed images)
- Pushes to GitHub Container Registry (ghcr.io)
- Triggers deployment workflow after successful builds
- Caching for faster builds

## Next Steps

### Immediate Actions Required

#### 1. Set Up Supabase Databases

You need to manually create the Supabase databases:

```sql
-- Already exists (from previous work)
-- CREATE DATABASE analytics;

-- Create new databases for the migration
CREATE DATABASE airbyte_internal;
CREATE DATABASE metabase_app;

-- In analytics database, create schemas
\c analytics
CREATE SCHEMA IF NOT EXISTS raw;
CREATE SCHEMA IF NOT EXISTS staging;
CREATE SCHEMA IF NOT EXISTS analytics;
```

Then run the initialization scripts:
```bash
psql "postgresql://postgres:[password]@db.[project-ref].supabase.co:6543/analytics?sslmode=require" \
  -f /Users/miriahpeterson/Code/go-projects/eleduck-analytics-connector/scripts/init-schemas.sql
```

#### 2. Update Foundry Values File

Edit `helm/eleduck-analytics/values-foundry.yaml` and replace `YOUR_PROJECT_REF` with your actual Supabase project reference:

```yaml
global:
  database:
    host: db.YOUR_PROJECT_REF.supabase.co  # Update this line
```

Also update in the `airbyte` section:
```yaml
airbyte:
  global:
    database:
      host: db.YOUR_PROJECT_REF.supabase.co  # Update this line
```

#### 3. Create Sealed Secrets

Install kubeseal CLI if not already installed:
```bash
brew install kubeseal
```

Create the Supabase credentials secret:
```bash
kubectl create secret generic supabase-credentials \
  --from-literal=username=postgres \
  --from-literal=password=YOUR_SUPABASE_PASSWORD \
  -n eleduck-analytics \
  --dry-run=client -o yaml | \
  kubeseal --format yaml --kubeconfig ~/.foundry/kubeconfig > supabase-credentials-sealed.yaml

kubectl apply -f supabase-credentials-sealed.yaml --kubeconfig ~/.foundry/kubeconfig
```

Create the GHCR pull secret:
```bash
kubectl create secret docker-registry ghcr-pull-secret \
  --docker-server=ghcr.io \
  --docker-username=Soypete \
  --docker-password=YOUR_GITHUB_PAT \
  -n eleduck-analytics \
  --dry-run=client -o yaml | \
  kubeseal --format yaml --kubeconfig ~/.foundry/kubeconfig > ghcr-pull-secret-sealed.yaml

kubectl apply -f ghcr-pull-secret-sealed.yaml --kubeconfig ~/.foundry/kubeconfig
```

Create the podcast scraper credentials (extract from 1Password):
```bash
# Use 1Password CLI to get the credentials
op item get "podcast-scraper-credentials" --vault SoypeteTech --format json | \
  jq -r '.fields[] | "--from-literal=\(.label)=\(.value)"' | \
  xargs kubectl create secret generic podcast-scraper-credentials \
    -n eleduck-analytics \
    --dry-run=client -o yaml | \
  kubeseal --format yaml --kubeconfig ~/.foundry/kubeconfig > podcast-scraper-credentials-sealed.yaml

kubectl apply -f podcast-scraper-credentials-sealed.yaml --kubeconfig ~/.foundry/kubeconfig
```

#### 4. Configure GitHub Secrets

Add the Foundry kubeconfig to GitHub secrets:

```bash
# Encode the kubeconfig
cat ~/.foundry/kubeconfig | base64 | pbcopy

# Then go to: https://github.com/Soypete/eleduck-analytics-connector/settings/secrets/actions
# Create new secret: KUBE_CONFIG
# Paste the base64-encoded content
```

#### 5. Test Local Deployment

Before pushing to GitHub, test the deployment locally:

```bash
# Render templates to verify
helm template eleduck-analytics helm/eleduck-analytics \
  -f helm/eleduck-analytics/values-foundry.yaml \
  --namespace eleduck-analytics

# Dry run
helm install eleduck-analytics helm/eleduck-analytics \
  -n eleduck-analytics \
  -f helm/eleduck-analytics/values-foundry.yaml \
  --dry-run --debug \
  --kubeconfig ~/.foundry/kubeconfig

# Actual deployment
helm upgrade --install eleduck-analytics helm/eleduck-analytics \
  -n eleduck-analytics \
  -f helm/eleduck-analytics/values-foundry.yaml \
  --wait \
  --timeout 10m \
  --kubeconfig ~/.foundry/kubeconfig
```

#### 6. Verify Deployment

```bash
# Check pods
kubectl get pods -n eleduck-analytics --kubeconfig ~/.foundry/kubeconfig

# Check services
kubectl get svc -n eleduck-analytics --kubeconfig ~/.foundry/kubeconfig

# Check ingress
kubectl get ingress -n eleduck-analytics --kubeconfig ~/.foundry/kubeconfig

# Check CronJobs
kubectl get cronjobs -n eleduck-analytics --kubeconfig ~/.foundry/kubeconfig
```

#### 7. Test Ingress Access

From a machine connected to Tailscale:

```bash
curl -k https://analytics.catalyst.local
```

Or open in browser: https://analytics.catalyst.local

### Phase 3: Database Migration (Pending)

Once the Helm deployment is working, you'll need to:

1. **Backup existing data** from the current postgres deployment
2. **Restore to Supabase** databases
3. **Verify data integrity**
4. **Update connection strings** in all applications

### Phase 5: Monitoring Integration (Future)

After the deployment is stable:

1. Create ServiceMonitors for Prometheus
2. Create Grafana dashboards
3. Set up alerting rules
4. Configure log aggregation with Loki

## Files Modified/Created

### New Files
- `helm/eleduck-analytics/Chart.yaml`
- `helm/eleduck-analytics/values.yaml`
- `helm/eleduck-analytics/values-foundry.yaml`
- `helm/eleduck-analytics/README.md`
- `helm/eleduck-analytics/.helmignore`
- `helm/eleduck-analytics/templates/_helpers.tpl`
- `helm/eleduck-analytics/templates/namespace.yaml`
- All subchart files (metabase, sqlmesh, podcast-scraper)
- `.github/workflows/deploy.yaml`
- `.github/workflows/build-images.yaml`
- `MIGRATION_STATUS.md` (this file)

### Existing Files (Unchanged)
- All files in `k8s/` directory (kept for reference during migration)
- Docker build files
- Application code

## Testing Checklist

Before considering the migration complete:

- [ ] Supabase databases created and initialized
- [ ] All sealed secrets created and applied
- [ ] `values-foundry.yaml` updated with correct Supabase host
- [ ] GitHub secret `KUBE_CONFIG` configured
- [ ] Helm chart deploys successfully
- [ ] All pods are running and healthy
- [ ] Ingress accessible via Tailscale
- [ ] Metabase UI loads successfully
- [ ] SQLMesh CronJob scheduled correctly
- [ ] Podcast Scraper CronJob scheduled correctly
- [ ] Airbyte UI accessible (if ingress enabled)
- [ ] Data migration from old postgres to Supabase completed
- [ ] Airbyte connections tested and working
- [ ] SQLMesh transformations running successfully
- [ ] Metabase dashboards displaying data correctly
- [ ] GitHub Actions workflows tested and working

## Rollback Plan

If issues occur:

1. **Helm Rollback:**
   ```bash
   helm rollback eleduck-analytics -n eleduck-analytics --kubeconfig ~/.foundry/kubeconfig
   ```

2. **Full Rollback to Kustomize:**
   ```bash
   helm uninstall eleduck-analytics -n eleduck-analytics --kubeconfig ~/.foundry/kubeconfig
   kubectl apply -k k8s/ --kubeconfig ~/.foundry/kubeconfig  # If needed
   ```

3. **Database Restore:**
   ```bash
   pg_restore -h <host> -U postgres -d <database> --clean --if-exists /path/to/backup.dump
   ```

## Known Issues / Notes

1. **Airbyte Version**: Updated to 1.9.2 (latest) instead of 0.90.0 (which doesn't exist)
2. **External Database**: Airbyte chart expects `global.database.user` to be set directly - this is configured via secretRef in our setup
3. **Ingress for Airbyte**: Not enabled by default in values files - enable if needed
4. **DuckDB Migration**: Simplified approach uses Supabase for all databases initially - DuckDB can be added later if needed

## Resources

- [Helm Documentation](https://helm.sh/docs/)
- [Airbyte Helm Chart](https://github.com/airbytehq/airbyte-platform-charts)
- [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets)
- [Contour Ingress](https://projectcontour.io/)
- [Longhorn Storage](https://longhorn.io/)

## Support

For issues or questions:
- GitHub Issues: https://github.com/Soypete/eleduck-analytics-connector/issues
- Check pod logs: `kubectl logs -n eleduck-analytics <pod-name>`
- Review Helm chart README: `helm/eleduck-analytics/README.md`
