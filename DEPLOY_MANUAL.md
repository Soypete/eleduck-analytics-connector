# Manual Deployment Guide - Zot Registry

Quick guide for manual deployment using Zot registry at `100.81.89.62:5000`.

## Architecture Overview

**Data Storage:**
- **Supabase PostgreSQL**: Transactional databases
  - `metabase_app` - Metabase application data
  - `analytics.raw.podcast_metrics` - Podcast scraper data (temporary)
- **MotherDuck (DuckDB Cloud)**: Analytics workloads
  - `eleduck_analytics` database with `raw`, `staging`, `analytics` schemas
  - Optimized for analytical queries and transformations

**Data Flow:**
1. **Podcast Scraper** → Writes to Supabase `analytics.raw.podcast_metrics`
2. **Custom Go Integrations** → Write directly to MotherDuck `raw` schema
   - Spotify analytics (issue #9)
   - Apple Podcasts analytics (issue #10)
   - YouTube analytics (issue #11)
   - Amazon Music analytics (issue #12)
3. **SQLMesh** → Transforms data from `raw` to `staging` & `analytics` schemas in MotherDuck
4. **Metabase** → Queries MotherDuck for dashboards
   - Metabase app data → Supabase `metabase_app`
   - Analytics queries → MotherDuck

## 1. Build and Push Images ✅

```bash
# Build and push all images to Zot
./scripts/build-and-push.sh

# Or specify custom registry
./scripts/build-and-push.sh 100.81.89.62:5000
```

This builds:
- `100.81.89.62:5000/eleduck/sqlmesh:latest` ✅
- `100.81.89.62:5000/eleduck/podcast-scraper:latest` ✅

**Note:** The script uses `--tls-verify=false` for the Zot registry since it's an insecure HTTP registry.

## 2. Set Up MotherDuck (DuckDB Cloud)

Your MotherDuck token is already in 1Password at: `op://pedro/MotherDuck_access/credential`

Initialize the MotherDuck database and schemas:

```bash
# This will create the analytics database with raw, staging, and analytics schemas
./scripts/motherduck-init.sh
```

This script:
- Fetches your MotherDuck token from 1Password
- Connects to MotherDuck
- Creates `analytics` database
- Creates `raw`, `staging`, and `analytics` schemas

## 3. Update Helm Values for Zot

The `values-zot.yaml` is already configured to use:
- Zot registry at 100.81.89.62:5000
- Supabase for Airbyte metadata and Metabase app database
- MotherDuck for analytics workloads

## 4. Store Secrets in OpenBao

```bash
# Port-forward to OpenBao
kubectl port-forward -n openbao-system svc/openbao 8200:8200 &
export OPENBAO_ADDR=http://localhost:8200

# Login
bao login

# Store Supabase credentials (for Airbyte metadata, Metabase app, and Podcast scraper)
bao kv put secret/eleduck-analytics/database \
    username=postgres.xafzfaqyjeetonxelopw \
    password=CKPR4vx0fx7JzFlR

# Store MotherDuck token (for SQLMesh and Airbyte destination)
bao kv put secret/eleduck-analytics/motherduck \
    token=$(op read "op://pedro/MotherDuck_access/credential")

# Store podcast credentials from 1Password
bao kv put secret/eleduck-analytics/podcast-scraper \
    apple_email=$(op read "op://pedro/apple_podcast/username") \
    apple_password=$(op read "op://pedro/apple_podcast/password") \
    spotify_sp_cookie=$(op read "op://pedro/spotify_sp_cookie/credential") \
    spotify_sp_key_cookie=$(op read "op://pedro/spotify_sp_key_cookie/credential") \
    amazon_session_cookie="" \
    youtube_api_key="" \
    youtube_access_token=""
```

**Note**: These paths (`secret/eleduck-analytics/*`) match the `${secret:...}` references in the Helm chart's secrets.yaml template. Foundry will automatically substitute these values when deploying.

## 5. Deploy via pedro-ops

Add to `pedro-ops/stack.yml` then apply:

```bash
cd /Users/miriahpeterson/Code/go-projects/pedro-ops
foundryctl stack apply stack.yml
```

## 6. Verify

```bash
# Check pods
kubectl get pods -n eleduck-analytics

# Check services
kubectl get svc -n eleduck-analytics

# Check ingress
kubectl get ingress -n eleduck-analytics

# Access Metabase (from Tailscale machine)
open https://analytics.catalyst.local
```

## Troubleshooting

### Build fails
```bash
# Check build logs
tail -f /private/tmp/claude-*/tasks/*.output

# Or rebuild manually
podman build -t 100.81.89.62:5000/eleduck/sqlmesh:latest -f docker/sqlmesh/Dockerfile .
podman push 100.81.89.62:5000/eleduck/sqlmesh:latest
```

### Image pull fails in cluster
```bash
# Test registry access from cluster
kubectl run test --rm -it --image=100.81.89.62:5000/eleduck/sqlmesh:latest -- /bin/sh
```

### Supabase connection fails
```bash
# Test from local
./scripts/supabase-test.sh

# Test from cluster
kubectl run psql-test --rm -it --image=postgres:16 -- \
  psql "postgresql://postgres:PASSWORD@aws-0-us-west-1.pooler.supabase.com:5432/postgres" -c "SELECT version();"
```
