# Eleduck Analytics Helm Chart

This Helm chart deploys the complete analytics pipeline for SoypeteTech, including:

- **Airbyte**: Data ingestion from various sources (YouTube, Twitch, Spotify, etc.)
- **Metabase**: Analytics dashboard and visualization
- **SQLMesh**: Data transformation and modeling
- **Podcast Scraper**: Automated podcast metrics collection

## Prerequisites

- Kubernetes cluster (tested on Foundry cluster)
- Helm 3.x
- kubectl configured with cluster access
- Sealed Secrets controller (for secret management)
- Longhorn storage class (for persistent volumes)
- Contour ingress controller
- Tailscale for network access

## Installation

### 1. Configure Supabase Database

Before deploying, ensure you have:
- A Supabase project with databases: `airbyte_internal`, `metabase_app`, `analytics`
- Database credentials stored in a Sealed Secret

### 2. Create Sealed Secrets

Create the database credentials secret:

```bash
kubectl create secret generic supabase-credentials \
  --from-literal=username=postgres \
  --from-literal=password=YOUR_PASSWORD \
  -n eleduck-analytics \
  --dry-run=client -o yaml | \
  kubeseal --format yaml > supabase-credentials-sealed.yaml

kubectl apply -f supabase-credentials-sealed.yaml
```

Create the GHCR pull secret:

```bash
kubectl create secret docker-registry ghcr-pull-secret \
  --docker-server=ghcr.io \
  --docker-username=YOUR_USERNAME \
  --docker-password=YOUR_GITHUB_PAT \
  -n eleduck-analytics \
  --dry-run=client -o yaml | \
  kubeseal --format yaml > ghcr-pull-secret-sealed.yaml

kubectl apply -f ghcr-pull-secret-sealed.yaml
```

Create the podcast scraper credentials:

```bash
kubectl create secret generic podcast-scraper-credentials \
  --from-literal=apple_email=YOUR_EMAIL \
  --from-literal=apple_password=YOUR_PASSWORD \
  --from-literal=spotify_sp_cookie=YOUR_COOKIE \
  --from-literal=spotify_sp_key_cookie=YOUR_KEY \
  --from-literal=amazon_session_cookie=YOUR_COOKIE \
  --from-literal=youtube_api_key=YOUR_KEY \
  --from-literal=youtube_access_token=YOUR_TOKEN \
  -n eleduck-analytics \
  --dry-run=client -o yaml | \
  kubeseal --format yaml > podcast-scraper-credentials-sealed.yaml

kubectl apply -f podcast-scraper-credentials-sealed.yaml
```

### 3. Update values-foundry.yaml

Edit `values-foundry.yaml` and update the Supabase host:

```yaml
global:
  database:
    host: db.YOUR_PROJECT_REF.supabase.co
```

### 4. Add Helm Repositories

```bash
helm repo add airbyte https://airbytehq.github.io/helm-charts
helm repo update
```

### 5. Deploy the Chart

```bash
helm upgrade --install eleduck-analytics . \
  -n eleduck-analytics \
  --create-namespace \
  -f values-foundry.yaml \
  --wait \
  --timeout 10m
```

## Accessing Services

With Tailscale connected to the Foundry cluster:

- **Metabase**: https://analytics.catalyst.local
- **Airbyte**: https://airbyte.catalyst.local (if ingress enabled)

## Configuration

### Global Values

| Parameter | Description | Default |
|-----------|-------------|---------|
| `global.namespace` | Kubernetes namespace | `eleduck-analytics` |
| `global.database.host` | Database host | `postgres.eleduck-analytics.svc.cluster.local` |
| `global.database.port` | Database port | `5432` |
| `global.database.sslMode` | SSL mode for database connections | `disable` |
| `global.ingress.enabled` | Enable ingress | `true` |
| `global.ingress.className` | Ingress class name | `contour` |
| `global.ingress.domain` | Base domain for ingress | `catalyst.local` |

### Component-Specific Values

#### Metabase

| Parameter | Description | Default |
|-----------|-------------|---------|
| `metabase.enabled` | Enable Metabase | `true` |
| `metabase.image.tag` | Metabase image tag | `v0.50.0` |
| `metabase.siteName` | Site name | `SoypeteTech Analytics` |
| `metabase.persistence.size` | PVC size | `10Gi` |

#### SQLMesh

| Parameter | Description | Default |
|-----------|-------------|---------|
| `sqlmesh.enabled` | Enable SQLMesh CronJob | `true` |
| `sqlmesh.schedule` | Cron schedule | `0 6 * * *` |
| `sqlmesh.image.tag` | SQLMesh image tag | `latest` |

#### Podcast Scraper

| Parameter | Description | Default |
|-----------|-------------|---------|
| `podcast-scraper.enabled` | Enable Podcast Scraper CronJob | `true` |
| `podcast-scraper.schedule` | Cron schedule | `0 2 * * *` |
| `podcast-scraper.config.showName` | Podcast show name | `domesticating ai` |

## Upgrading

To upgrade the deployment:

```bash
helm upgrade eleduck-analytics . \
  -n eleduck-analytics \
  -f values-foundry.yaml
```

## Uninstalling

To uninstall the chart:

```bash
helm uninstall eleduck-analytics -n eleduck-analytics
```

**Note**: This will not delete PersistentVolumeClaims. Delete them manually if needed:

```bash
kubectl delete pvc -n eleduck-analytics --all
```

## Troubleshooting

### Supabase Pooler and Prepared Statements

**Important**: Airbyte requires PostgreSQL prepared statement support, which Supabase's connection pooler (PgBouncer in transaction mode) does not provide properly.

**Symptoms**:
- Bootloader fails with error: `prepared statement "S_1" already exists`
- Airbyte components crash during database initialization

**Solution**: Configure Airbyte to use direct database connection (port 5432) instead of pooler (port 6543):

```yaml
airbyte:
  global:
    database:
      port: 5432  # Direct connection, not pooler
```

**Note**: Metabase and other components can use the pooler (port 6543) without issues. Only Airbyte requires the direct connection.

### NFS Client Requirement for Longhorn RWX Volumes

Longhorn's ReadWriteMany (RWX) volumes require NFS client utilities on all cluster nodes.

**Symptoms**:
- Pods stuck in `ContainerCreating`
- Mount errors: `bad option; for several filesystems (e.g. nfs, cifs) you might need a /sbin/mount.<type> helper program`

**Solution**: Install nfs-common on all nodes:

```bash
for host in <node-ips>; do
  ssh root@$host 'apt-get update && apt-get install -y nfs-common'
done
```

### Check pod status

```bash
kubectl get pods -n eleduck-analytics
```

### View logs

```bash
# Metabase logs
kubectl logs -n eleduck-analytics -l app=metabase

# SQLMesh job logs
kubectl logs -n eleduck-analytics -l app=sqlmesh

# Podcast scraper job logs
kubectl logs -n eleduck-analytics -l app=podcast-scraper
```

### Check CronJob status

```bash
kubectl get cronjobs -n eleduck-analytics
```

### Manually trigger a CronJob

```bash
# SQLMesh
kubectl create job --from=cronjob/sqlmesh-runner -n eleduck-analytics sqlmesh-manual-$(date +%s)

# Podcast Scraper
kubectl create job --from=cronjob/podcast-metrics-scraper -n eleduck-analytics scraper-manual-$(date +%s)
```

## Development

### Linting

```bash
helm lint .
```

### Template Rendering

To see the rendered templates without deploying:

```bash
helm template eleduck-analytics . -f values-foundry.yaml
```

### Dry Run

Test the installation without actually deploying:

```bash
helm install eleduck-analytics . \
  -n eleduck-analytics \
  -f values-foundry.yaml \
  --dry-run --debug
```

## CI/CD

The chart is automatically deployed via GitHub Actions when changes are pushed to the `main` branch.

- **Image builds**: `.github/workflows/build-images.yaml`
- **Deployment**: `.github/workflows/deploy.yaml`

## License

MIT
