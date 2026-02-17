# Quick Start: Deploy to Foundry Cluster

This guide will get your analytics pipeline running on the Foundry cluster in ~30 minutes.

## Prerequisites Check

✅ Sealed Secrets controller installed (done)
✅ `eleduck-analytics` namespace created (done)
✅ Foundry cluster access at `~/.foundry/kubeconfig` (done)
✅ Helm dependencies downloaded (done)

## 5-Step Deployment

### Step 1: Get Your Supabase Details (5 min)

1. Log in to your Supabase project
2. Get the connection string from Settings > Database
3. Extract:
   - Project Reference: `xyz123` from `db.xyz123.supabase.co`
   - Password: Your postgres password

### Step 2: Update Configuration (2 min)

Edit `helm/eleduck-analytics/values-foundry.yaml`:

```bash
# Replace YOUR_PROJECT_REF with your actual project reference
sed -i '' 's/YOUR_PROJECT_REF/xyz123/g' helm/eleduck-analytics/values-foundry.yaml
```

Or manually edit these two lines:
- Line ~6: `host: db.YOUR_PROJECT_REF.supabase.co`
- Line ~26: `host: db.YOUR_PROJECT_REF.supabase.co`

### Step 3: Create Secrets (10 min)

Create the Supabase credentials secret:

```bash
export SUPABASE_PASSWORD="your-password-here"

kubectl create secret generic supabase-credentials \
  --from-literal=username=postgres \
  --from-literal=password=$SUPABASE_PASSWORD \
  -n eleduck-analytics \
  --dry-run=client -o yaml | \
  kubeseal --format yaml --kubeconfig ~/.foundry/kubeconfig > /tmp/supabase-sealed.yaml

kubectl apply -f /tmp/supabase-sealed.yaml --kubeconfig ~/.foundry/kubeconfig
```

Create the GitHub Container Registry pull secret:

```bash
export GITHUB_PAT="your-github-pat-here"

kubectl create secret docker-registry ghcr-pull-secret \
  --docker-server=ghcr.io \
  --docker-username=Soypete \
  --docker-password=$GITHUB_PAT \
  -n eleduck-analytics \
  --dry-run=client -o yaml | \
  kubeseal --format yaml --kubeconfig ~/.foundry/kubeconfig > /tmp/ghcr-sealed.yaml

kubectl apply -f /tmp/ghcr-sealed.yaml --kubeconfig ~/.foundry/kubeconfig
```

Create the podcast scraper credentials:

```bash
# If you have the credentials in 1Password, use:
op item get "podcast-scraper" --vault SoypeteTech --format json | \
  jq -r '.fields[] | "--from-literal=\(.label)=\(.value)"' | \
  xargs kubectl create secret generic podcast-scraper-credentials \
    -n eleduck-analytics \
    --dry-run=client -o yaml | \
  kubeseal --format yaml --kubeconfig ~/.foundry/kubeconfig > /tmp/podcast-sealed.yaml

kubectl apply -f /tmp/podcast-sealed.yaml --kubeconfig ~/.foundry/kubeconfig

# Or manually create it:
kubectl create secret generic podcast-scraper-credentials \
  --from-literal=apple_email="" \
  --from-literal=apple_password="" \
  --from-literal=spotify_sp_cookie="" \
  --from-literal=spotify_sp_key_cookie="" \
  --from-literal=amazon_session_cookie="" \
  --from-literal=youtube_api_key="" \
  --from-literal=youtube_access_token="" \
  -n eleduck-analytics \
  --dry-run=client -o yaml | \
  kubeseal --format yaml --kubeconfig ~/.foundry/kubeconfig > /tmp/podcast-sealed.yaml

kubectl apply -f /tmp/podcast-sealed.yaml --kubeconfig ~/.foundry/kubeconfig
```

Verify secrets:

```bash
kubectl get sealedsecrets -n eleduck-analytics --kubeconfig ~/.foundry/kubeconfig
kubectl get secrets -n eleduck-analytics --kubeconfig ~/.foundry/kubeconfig
```

### Step 4: Deploy the Chart (5 min)

```bash
helm upgrade --install eleduck-analytics helm/eleduck-analytics \
  -n eleduck-analytics \
  -f helm/eleduck-analytics/values-foundry.yaml \
  --wait \
  --timeout 10m \
  --kubeconfig ~/.foundry/kubeconfig
```

Watch the deployment:

```bash
watch kubectl get pods -n eleduck-analytics --kubeconfig ~/.foundry/kubeconfig
```

### Step 5: Verify and Access (5 min)

Check everything is running:

```bash
kubectl get all -n eleduck-analytics --kubeconfig ~/.foundry/kubeconfig
```

Expected output:
```
NAME                                READY   STATUS    RESTARTS   AGE
pod/metabase-xxxxx-xxxxx            1/1     Running   0          2m
pod/airbyte-server-xxxxx-xxxxx      1/1     Running   0          2m
pod/airbyte-webapp-xxxxx-xxxxx      1/1     Running   0          2m
pod/airbyte-worker-xxxxx-xxxxx      1/1     Running   0          2m
pod/airbyte-temporal-xxxxx-xxxxx    1/1     Running   0          2m

NAME                         TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)
service/metabase             ClusterIP   10.43.x.x       <none>        3000/TCP
service/airbyte-server       ClusterIP   10.43.x.x       <none>        8001/TCP
service/airbyte-webapp       ClusterIP   10.43.x.x       <none>        80/TCP

NAME                              SCHEDULE      SUSPEND   ACTIVE   LAST SCHEDULE
cronjob.batch/sqlmesh-runner      0 6 * * *     False     0        <none>
cronjob.batch/podcast-metrics-scraper   0 2 * * *     False     0        <none>
```

Access Metabase (from Tailscale-connected machine):

```bash
# Open in browser
open https://analytics.catalyst.local
```

## Troubleshooting

### Pods not starting?

```bash
# Check pod logs
kubectl logs -n eleduck-analytics -l app=metabase --kubeconfig ~/.foundry/kubeconfig

# Describe pod for events
kubectl describe pod -n eleduck-analytics <pod-name> --kubeconfig ~/.foundry/kubeconfig
```

### ImagePullBackOff error?

The GHCR secret might not be created correctly:

```bash
# Verify the secret
kubectl get secret ghcr-pull-secret -n eleduck-analytics -o yaml --kubeconfig ~/.foundry/kubeconfig

# Recreate if needed (see Step 3)
```

### Database connection errors?

Check the Supabase credentials:

```bash
# Verify the secret exists
kubectl get secret supabase-credentials -n eleduck-analytics --kubeconfig ~/.foundry/kubeconfig

# Test connection manually
psql "postgresql://postgres:PASSWORD@db.PROJECT_REF.supabase.co:6543/analytics?sslmode=require" -c "SELECT version();"
```

### Ingress not accessible?

```bash
# Check ingress status
kubectl get ingress -n eleduck-analytics --kubeconfig ~/.foundry/kubeconfig

# Verify Tailscale DNS
ping analytics.catalyst.local

# Check Contour is running
kubectl get pods -n projectcontour --kubeconfig ~/.foundry/kubeconfig
```

## Next: Enable CI/CD

Once manual deployment works, enable GitHub Actions:

1. Encode kubeconfig:
   ```bash
   cat ~/.foundry/kubeconfig | base64 | pbcopy
   ```

2. Add to GitHub secrets:
   - Go to: https://github.com/Soypete/eleduck-analytics-connector/settings/secrets/actions
   - Create new secret: `KUBE_CONFIG`
   - Paste the base64 content

3. Push changes:
   ```bash
   git add .
   git commit -m "feat: add Helm charts and GitHub Actions deployment"
   git push origin main
   ```

4. Watch the deployment:
   - Go to: https://github.com/Soypete/eleduck-analytics-connector/actions
   - Click on the latest workflow run
   - Monitor the deployment steps

## Common Commands

```bash
# Set kubeconfig alias for convenience
alias kf='kubectl --kubeconfig ~/.foundry/kubeconfig'

# Watch pods
watch kf get pods -n eleduck-analytics

# Get logs
kf logs -n eleduck-analytics -l app=metabase --tail=100 -f

# Port forward Metabase (alternative to ingress)
kf port-forward -n eleduck-analytics svc/metabase 3000:3000

# Manually trigger a CronJob
kf create job --from=cronjob/sqlmesh-runner -n eleduck-analytics sqlmesh-test-$(date +%s)

# Restart a deployment
kf rollout restart deployment/metabase -n eleduck-analytics

# Get Helm status
helm status eleduck-analytics -n eleduck-analytics --kubeconfig ~/.foundry/kubeconfig

# Upgrade with new values
helm upgrade eleduck-analytics helm/eleduck-analytics \
  -n eleduck-analytics \
  -f helm/eleduck-analytics/values-foundry.yaml \
  --kubeconfig ~/.foundry/kubeconfig
```

## Success Checklist

- [ ] All secrets created and applied
- [ ] `values-foundry.yaml` updated with Supabase host
- [ ] Helm deployment successful
- [ ] All pods running (check with `kubectl get pods`)
- [ ] Metabase accessible at https://analytics.catalyst.local
- [ ] CronJobs scheduled (check with `kubectl get cronjobs`)
- [ ] Database connections working (check pod logs)
- [ ] GitHub Actions configured and tested

## What's Next?

After successful deployment:

1. **Migrate Data**: Copy existing data from old postgres to Supabase
2. **Configure Airbyte**: Set up data sources and destinations
3. **Run SQLMesh**: Test transformations
4. **Set Up Dashboards**: Configure Metabase dashboards
5. **Monitor**: Add Prometheus/Grafana dashboards

See `MIGRATION_STATUS.md` for the complete plan.
