# Airbyte Configuration

This directory contains configuration templates for Airbyte sources and destinations.

## Deployment

Airbyte is deployed via Helm:

```bash
# Add Airbyte Helm repo
helm repo add airbyte https://airbytehq.github.io/helm-charts
helm repo update

# Deploy Airbyte
helm upgrade --install airbyte airbyte/airbyte \
  -f k8s/airbyte/values.yaml \
  -n eleduck-analytics

# Wait for pods to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=airbyte -n eleduck-analytics --timeout=300s
```

## Accessing the UI

```bash
# Port forward to local machine
make port-forward-airbyte

# Open http://localhost:8080
```

## Setting Up Sources

### Prerequisites

Create 1Password items for each source. Required fields vary by source.

### YouTube Analytics

1Password item: `airbyte-youtube`
- `client_id` - Google OAuth client ID
- `client_secret` - Google OAuth client secret
- `refresh_token` - OAuth refresh token

Setup:
1. Create OAuth 2.0 credentials in Google Cloud Console
2. Enable YouTube Analytics API
3. Generate refresh token using OAuth playground

### Twitch

1Password item: `airbyte-twitch`
- `client_id` - Twitch application client ID
- `client_secret` - Twitch application client secret
- `user_id` - Your Twitch user ID

Setup:
1. Create application at https://dev.twitch.tv/console
2. Get user ID from Twitch API or third-party tool

### Twitter/X

1Password item: `airbyte-twitter`
- `api_key` - Twitter API key
- `api_secret` - Twitter API secret
- `bearer_token` - Bearer token for API v2

**Note:** Twitter API now requires paid access ($100/month minimum).

### LinkedIn

1Password item: `airbyte-linkedin`
- `client_id` - LinkedIn app client ID
- `client_secret` - LinkedIn app client secret
- `refresh_token` - OAuth refresh token
- `organization_id` - Company page ID

Setup:
1. Create app at LinkedIn Developer Portal
2. Request Marketing Developer Platform access
3. Add company page to app

### GitHub

1Password item: `airbyte-github`
- `personal_access_token` - Classic PAT with repo, read:org, read:user scopes

Setup:
1. Generate PAT at https://github.com/settings/tokens
2. Select scopes: repo, read:org, read:user

### Stripe

1Password item: `airbyte-stripe`
- `secret_key` - Stripe secret key (use restricted key)
- `account_id` - Stripe account ID

Setup:
1. Get keys from Stripe Dashboard > Developers > API keys
2. Create restricted key with read-only access

### Notion

1Password item: `airbyte-notion`
- `api_token` - Notion integration token

Setup:
1. Create integration at https://www.notion.so/my-integrations
2. Share relevant pages/databases with integration

## Connection Naming Convention

- Source: `src_<platform>` (e.g., `src_youtube`, `src_github`)
- Destination: `dest_postgres_raw`
- Connection: `<platform>_to_postgres` (e.g., `youtube_to_postgres`)

## Sync Schedule

All sources sync daily at 2am UTC, before DBT runs at 6am UTC.

## Expected Raw Tables

After syncing, these tables will appear in the `raw` schema:

### YouTube
- `raw.youtube_videos`
- `raw.youtube_channel_stats`
- `raw.youtube_video_metrics`

### Twitch
- `raw.twitch_streams`
- `raw.twitch_followers`
- `raw.twitch_videos`

### Twitter
- `raw.twitter_tweets`
- `raw.twitter_user_metrics`

### LinkedIn
- `raw.linkedin_posts`
- `raw.linkedin_page_stats`

### GitHub
- `raw.github_repositories`
- `raw.github_commits`
- `raw.github_pull_requests`
- `raw.github_issues`
- `raw.github_stargazers`

### Stripe
- `raw.stripe_charges`
- `raw.stripe_customers`
- `raw.stripe_subscriptions`
- `raw.stripe_invoices`

### Notion
- `raw.notion_pages`
- `raw.notion_databases`

## Troubleshooting

### Sync Failures

Check connector logs:
```bash
kubectl logs -n eleduck-analytics -l airbyte=worker -f
```

### Connection Issues

Verify PostgreSQL is accessible:
```bash
kubectl exec -it deploy/airbyte-server -n eleduck-analytics -- \
  nc -zv postgres.eleduck-analytics.svc.cluster.local 5432
```

### Rate Limiting

Most APIs have rate limits. Airbyte handles retries, but for persistent issues:
- Check API quotas in provider's dashboard
- Reduce sync frequency
- Use incremental sync modes
