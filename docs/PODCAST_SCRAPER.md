# Podcast Metrics Scraper

This document describes the podcast metrics scraping system for "domesticating ai" across multiple platforms.

## Overview

The podcast metrics scraper collects analytics data from 4 platforms:

1. **Apple Podcasts** - Plays, listeners, engaged listeners, followers
2. **Spotify** - Starts, streams, listeners, followers
3. **Amazon Music** - Starts, plays, listeners, engaged listeners
4. **YouTube** - Views, likes, comments, watch time, subscribers

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                   CronJob (Daily at 2 AM)                   │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│              Podcast Scraper Orchestrator                   │
│  (cmd/podcast-scraper/main.go)                             │
└─────────────────────────────────────────────────────────────┘
                            │
            ┌───────────────┼───────────────┐
            ▼               ▼               ▼               ▼
    ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐
    │Apple Podcasts│ │   Spotify    │ │Amazon Music  │ │   YouTube    │
    │   Scraper    │ │   Scraper    │ │   Scraper    │ │   Scraper    │
    └──────────────┘ └──────────────┘ └──────────────┘ └──────────────┘
            │               │               │               │
            └───────────────┼───────────────┘               │
                            ▼                               ▼
                    ┌──────────────────────────────────────────┐
                    │      PostgreSQL + DuckDB                 │
                    │  ┌────────────────────────────────────┐  │
                    │  │ raw.podcasts                       │  │
                    │  │ raw.podcast_episodes               │  │
                    │  │ raw.podcast_episode_metrics        │  │
                    │  │ raw.podcast_show_metrics           │  │
                    │  │ raw.podcast_comments               │  │
                    │  └────────────────────────────────────┘  │
                    └──────────────────────────────────────────┘
```

## Database Schema

### Tables

**raw.podcasts**
- Stores podcast/show information per platform
- Fields: show_name, platform, platform_id, description, author, categories, language

**raw.podcast_episodes**
- Individual episodes across all platforms
- Fields: episode_title, platform_episode_id, description, duration, publish_date, season/episode numbers

**raw.podcast_episode_metrics**
- Daily metrics per episode
- Common fields: plays, listeners, engaged_listeners, downloads, streams, completion_rate
- YouTube-specific: views, likes, dislikes, comments_count, shares, watch_time_minutes, subscribers_gained/lost
- Geographic: top_countries, top_cities
- Device breakdown

**raw.podcast_show_metrics**
- Daily aggregate metrics for the entire show
- Rollup of episode metrics plus show-level followers/subscribers

**raw.podcast_comments**
- Comments from platforms that support them (YouTube)
- Includes comment text, author, likes, replies

**raw.podcast_scraper_runs**
- Audit log of scraper executions
- Tracks status, episodes processed, metrics collected, errors

### Views

**staging.podcast_metrics_latest**
- Last 30 days of episode metrics across all platforms

**analytics.podcast_performance_summary**
- Cross-platform performance comparison
- Aggregates total plays, listeners, views, downloads, etc. by platform

## Platform APIs

### Apple Podcasts Connect
- **Status**: No official public API
- **Implementation**: Custom scraper using Apple Podcasts Connect endpoints
- **Authentication**: Email/password (requires Apple ID)
- **Metrics**: Plays, Listeners, Engaged Listeners, Followers
- **Limitations**: No comment support

### Spotify for Podcasters
- **Status**: No official public API (as of 2026)
- **Implementation**: Reverse-engineered internal API
- **Authentication**: Session cookies (sp_dc, sp_key)
- **Metrics**: Starts, Streams, Listeners, Followers
- **Limitations**: Requires browser cookie extraction; no comment support

### Amazon Music for Podcasters
- **Status**: Web API in private beta (metadata only)
- **Implementation**: Custom scraper for analytics dashboard
- **Authentication**: Session cookie
- **Metrics**: Starts, Plays, Listeners, Engaged Listeners, Followers
- **Limitations**: No comment support

### YouTube Analytics
- **Status**: Official YouTube Analytics API v2
- **Implementation**: YouTube Data API v3 + Analytics API
- **Authentication**: API Key + OAuth 2.0
- **Metrics**: Views, Likes, Comments, Watch Time, Subscribers, Demographics
- **Advantages**: Full API support, comment data available

## Setup Instructions

### 1. Prerequisites

- Kubernetes cluster with eleduck-analytics namespace
- 1Password Operator installed and configured
- PostgreSQL + DuckDB database deployed
- Access to all 4 platform accounts

### 2. Database Migration

Run the database migration to create the podcast metrics schema:

```bash
# The migration will run automatically via main.go
# Or manually apply:
goose -dir database/migrations postgres "connection-string" up
```

### 3. Obtain Platform Credentials

#### Apple Podcasts
1. Log into https://podcastsconnect.apple.com
2. Use your Apple ID credentials
3. Store in 1Password as `apple_email` and `apple_password`

#### Spotify
1. Log into https://podcasters.spotify.com
2. Open browser DevTools (F12) → Application → Cookies
3. Copy values for `sp_dc` and `sp_key` cookies
4. Store in 1Password as `spotify_sp_cookie` and `spotify_sp_key_cookie`

#### Amazon Music
1. Log into https://podcasters.amazon.com
2. Open browser DevTools (F12) → Application → Cookies
3. Copy session cookie value
4. Store in 1Password as `amazon_session_cookie`

#### YouTube
1. Go to https://console.cloud.google.com
2. Create/select a project
3. Enable YouTube Data API v3 and YouTube Analytics API
4. Create credentials:
   - **API Key**: For public data (video metadata)
   - **OAuth 2.0**: For analytics data (requires channel owner authorization)
5. Store in 1Password as `youtube_api_key` and `youtube_access_token`

### 4. Configure 1Password

Create a 1Password item named `podcast-scraper-credentials` in the `eleduck-analytics` vault with all the credentials above.

### 5. Deploy to Kubernetes

```bash
# Build and push Docker image
docker build -f docker/podcast-scraper/Dockerfile -t ghcr.io/soypete/podcast-scraper:latest .
docker push ghcr.io/soypete/podcast-scraper:latest

# Apply Kubernetes manifests
kubectl apply -k k8s/podcast-scraper/
```

### 6. Verify Deployment

```bash
# Check CronJob
kubectl get cronjobs -n eleduck-analytics

# Check secrets (from 1Password)
kubectl get secrets -n eleduck-analytics podcast-scraper-credentials

# Manually trigger a job for testing
kubectl create job --from=cronjob/podcast-metrics-scraper test-run -n eleduck-analytics

# View logs
kubectl logs -n eleduck-analytics -l app=podcast-scraper
```

## Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `RUN_MODE` | Execution mode: `once` or `scheduled` | `once` |
| `SHOW_NAME` | Podcast show name | `domesticating ai` |
| `LOOKBACK_DAYS` | Days of historical data to fetch | `7` |
| `SCHEDULE_INTERVAL` | Interval for scheduled mode | `24h` |
| `DB_HOST` | PostgreSQL host | `localhost` |
| `DB_PORT` | PostgreSQL port | `5432` |
| `DB_NAME` | Database name | `analytics` |
| `DB_USER` | Database username | From secret |
| `DB_PASSWORD` | Database password | From secret |

### CronJob Schedule

The scraper runs daily at 2 AM UTC. Modify `k8s/podcast-scraper/cronjob.yaml` to change the schedule:

```yaml
schedule: "0 2 * * *"  # Cron format: minute hour day month weekday
```

## Metrics Collected

### Episode-Level Metrics
- **Audience**: Plays, Listeners, Engaged Listeners, Views
- **Engagement**: Likes, Comments, Shares, Completion Rate
- **Time**: Watch Time, Average View/Listen Duration
- **Growth**: Followers/Subscribers Gained/Lost
- **Geography**: Top Countries, Top Cities
- **Devices**: Device breakdown (mobile/desktop/tablet)

### Show-Level Metrics
- Aggregated totals across all episodes
- Overall follower/subscriber counts
- Platform-wide engagement metrics

### Comments (YouTube only)
- Comment text, author, timestamp
- Like counts, reply threads
- Parent-child comment relationships

## Querying the Data

### Latest 30 Days Summary
```sql
SELECT * FROM staging.podcast_metrics_latest
ORDER BY metric_date DESC;
```

### Cross-Platform Performance
```sql
SELECT * FROM analytics.podcast_performance_summary
ORDER BY total_plays DESC;
```

### Top Episodes by Platform
```sql
SELECT
    p.platform,
    pe.episode_title,
    SUM(pem.plays) as total_plays,
    SUM(pem.views) as total_views,
    AVG(pem.completion_rate) as avg_completion
FROM raw.podcast_episode_metrics pem
JOIN raw.podcast_episodes pe ON pem.episode_id = pe.id
JOIN raw.podcasts p ON pe.podcast_id = p.id
WHERE pem.metric_date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY p.platform, pe.episode_title
ORDER BY total_plays DESC
LIMIT 10;
```

### YouTube Comments Analysis
```sql
SELECT
    pe.episode_title,
    COUNT(*) as comment_count,
    AVG(pc.likes_count) as avg_comment_likes
FROM raw.podcast_comments pc
JOIN raw.podcast_episodes pe ON pc.episode_id = pe.id
JOIN raw.podcasts p ON pe.podcast_id = p.id
WHERE p.platform = 'youtube'
GROUP BY pe.episode_title
ORDER BY comment_count DESC;
```

## Troubleshooting

### Authentication Failures

**Apple Podcasts**: Check if 2FA is enabled; may need app-specific password
**Spotify**: Cookies expire; re-extract from fresh browser session
**Amazon**: Session cookies expire; log in again and update
**YouTube**: OAuth tokens expire; refresh or re-authorize

### Scraper Fails to Run

```bash
# Check pod logs
kubectl logs -n eleduck-analytics -l app=podcast-scraper --tail=100

# Check CronJob history
kubectl get jobs -n eleduck-analytics

# Describe CronJob for events
kubectl describe cronjob podcast-metrics-scraper -n eleduck-analytics
```

### Database Connection Issues

```bash
# Verify database is running
kubectl get pods -n eleduck-analytics -l app=postgres

# Test connection from scraper pod
kubectl run -it --rm debug --image=postgres:16 -n eleduck-analytics -- \
  psql -h postgres-service -U postgres -d analytics
```

### Missing Metrics

Check `raw.podcast_scraper_runs` table for errors:

```sql
SELECT * FROM raw.podcast_scraper_runs
WHERE status = 'failed'
ORDER BY run_started_at DESC;
```

## API Rate Limits

- **YouTube**: 10,000 quota units/day (each API call costs 1-100 units)
- **Apple/Spotify/Amazon**: Unofficial APIs have unknown limits; scraper uses reasonable delays

## Future Enhancements

- [ ] Add Airbyte integration for YouTube (native connector available)
- [ ] Automated OAuth token refresh for YouTube
- [ ] Alerting on scraper failures
- [ ] Metabase dashboards for visualization
- [ ] Additional platforms (Overcast, Pocket Casts, etc.)
- [ ] Sentiment analysis on YouTube comments
- [ ] Automated episode performance predictions

## References

- [Apple Podcasts Connect](https://podcastsconnect.apple.com)
- [Spotify for Podcasters](https://podcasters.spotify.com)
- [Amazon Music for Podcasters](https://podcasters.amazon.com)
- [YouTube Analytics API](https://developers.google.com/youtube/analytics)
- [Airbyte YouTube Analytics Connector](https://docs.airbyte.com/integrations/sources/youtube-analytics)
