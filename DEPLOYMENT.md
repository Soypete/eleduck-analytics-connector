# Deployment Guide: Eleduck Analytics on Foundry Cluster

This guide explains how to deploy the analytics pipeline using Foundry's stack.yaml with OpenBao secret management.

## Architecture

- **Secret Management**: OpenBao stores all sensitive credentials
- **Deployment**: Foundry stack.yaml with `${secret:path:key}` references
- **Database**: Supabase PostgreSQL (external)
- **Storage**: Longhorn for persistent volumes
- **Networking**: Tailscale for ingress (*.catalyst.local)
- **Monitoring**: Prometheus, Loki, Grafana

## Prerequisites

1. **Foundry cluster** with:
   - OpenBao deployed and initialized
   - Longhorn storage class
   - Contour ingress controller
   - Tailscale networking

2. **Local tools**:
   ```bash
   # OpenBao CLI
   brew install openbao/tap/openbao

   # 1Password CLI
   brew install 1password-cli

   # Foundry CLI (if available)
   # foundryctl or similar
   ```

3. **Supabase project**:
   - Project created and active
   - Databases: `airbyte_internal`, `metabase_app`, `analytics`
   - Connection pooler enabled (port 6543)

## Step 1: Connect to OpenBao

```bash
# Port-forward to OpenBao (adjust namespace if needed)
kubectl port-forward -n openbao-system svc/openbao 8200:8200 &

# Set OpenBao address
export OPENBAO_ADDR=http://localhost:8200

# Login to OpenBao (use your auth method)
bao login
```

## Step 2: Sync Secrets from 1Password to OpenBao

```bash
# Run the sync script
./scripts/sync-secrets-to-openbao.sh
```

This will:
- Extract Supabase credentials from 1Password
- Store them in OpenBao at `secret/eleduck-analytics/database`
- Create placeholder podcast scraper credentials
- Store GitHub token (if GITHUB_TOKEN env var is set)

### Manual Secret Addition

If you need to add/update secrets manually:

```bash
# Database credentials
bao kv put secret/eleduck-analytics/database \
    username=postgres \
    password=YOUR_PASSWORD \
    host=db.xafzfaqyjeetonxelopw.supabase.co

# GitHub token
bao kv put secret/eleduck-analytics/github \
    token=YOUR_GITHUB_PAT

# Podcast scraper credentials
bao kv put secret/eleduck-analytics/podcast-scraper \
    apple_email=your@email.com \
    apple_password=YOUR_PASSWORD \
    spotify_sp_cookie=YOUR_COOKIE \
    # ... etc
```

### Verify Secrets

```bash
# List secrets
bao kv list secret/eleduck-analytics

# Read a secret
bao kv get secret/eleduck-analytics/database
```

## Step 3: Deploy via Foundry Stack

```bash
# If using Foundry CLI
foundryctl stack apply stack.yaml

# Or if using kubectl directly
kubectl apply -f stack.yaml
```

The stack.yaml will:
1. Create the `eleduck-analytics` namespace
2. Create Kubernetes secrets from OpenBao references
3. Deploy the Helm chart with values
4. Set up RBAC for Airbyte

## Step 4: Verify Deployment

```bash
# Check stack status
foundryctl stack status eleduck-analytics
# Or
kubectl get all -n eleduck-analytics

# Check pods
kubectl get pods -n eleduck-analytics

# Check secrets (should show as created from OpenBao)
kubectl get secrets -n eleduck-analytics

# Check Helm release
helm list -n eleduck-analytics
```

## Step 5: Access Services

From a machine connected to Tailscale:

```bash
# Metabase
open https://analytics.catalyst.local

# Or port-forward locally
kubectl port-forward -n eleduck-analytics svc/metabase 3000:3000
open http://localhost:3000
```

## Updating Secrets

When secrets need to be updated:

```bash
# Update in OpenBao
bao kv put secret/eleduck-analytics/database password=NEW_PASSWORD

# Re-apply the stack (this will recreate secrets)
foundryctl stack apply stack.yaml

# Or manually delete the secret to force recreation
kubectl delete secret supabase-credentials -n eleduck-analytics
kubectl apply -f stack.yaml
```

## Troubleshooting

### Pods stuck in CreateContainerConfigError

Check if secrets exist:
```bash
kubectl get secret supabase-credentials -n eleduck-analytics -o yaml
```

Verify OpenBao values are populated (not `${secret:...}` placeholders):
```bash
kubectl get secret supabase-credentials -n eleduck-analytics -o jsonpath='{.data.password}' | base64 -d
```

### Database connection errors

Test from within cluster:
```bash
kubectl run psql-test --rm -it --image=postgres:16 -- \
  psql "postgresql://postgres:PASSWORD@db.xafzfaqyjeetonxelopw.supabase.co:6543/postgres?sslmode=require" -c "SELECT version();"
```

### Airbyte bootloader fails

Check RBAC permissions:
```bash
kubectl get role,rolebinding -n eleduck-analytics | grep airbyte

# Should see:
# - role: airbyte-secrets-access
# - rolebinding: airbyte-secrets-binding
```

Check service account:
```bash
kubectl get serviceaccount airbyte -n eleduck-analytics
```

### Logs

```bash
# Metabase logs
kubectl logs -n eleduck-analytics -l app=metabase --tail=100 -f

# Airbyte bootloader logs
kubectl logs -n eleduck-analytics -l app.kubernetes.io/component=airbyte-bootloader

# Airbyte server logs
kubectl logs -n eleduck-analytics -l app.kubernetes.io/name=server
```

## CI/CD Integration

For GitHub Actions, update the workflow to use OpenBao:

```yaml
- name: Load secrets from OpenBao
  run: |
    # Port forward to OpenBao
    kubectl port-forward -n openbao-system svc/openbao 8200:8200 &

    # Login and fetch secrets
    export OPENBAO_ADDR=http://localhost:8200
    bao login -method=kubernetes role=github-actions

    # Export as env vars for stack apply
    export DB_PASSWORD=$(bao kv get -field=password secret/eleduck-analytics/database)
```

## Rollback

```bash
# Helm rollback
helm rollback eleduck-analytics -n eleduck-analytics

# Or delete and redeploy
foundryctl stack delete eleduck-analytics
foundryctl stack apply stack.yaml
```

## Security Notes

- **Never commit secrets** to git
- **OpenBao secrets are encrypted** at rest
- **Kubernetes secrets** are created dynamically from OpenBao
- **Access control** via OpenBao policies
- **Audit logs** in OpenBao for secret access

## Next Steps

1. ✅ Deploy with OpenBao integration
2. ⏳ Migrate existing data to Supabase
3. ⏳ Set up Prometheus ServiceMonitors
4. ⏳ Create Grafana dashboards
5. ⏳ Configure Airbyte connections
6. ⏳ Set up SQLMesh transformations
7. ⏳ Build Metabase dashboards

## Support

- Foundry docs: [foundry.dev](https://foundry.dev)
- OpenBao docs: [openbao.org](https://openbao.org)
- Helm chart: `helm/eleduck-analytics/README.md`
