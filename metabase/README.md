# Metabase Configuration

Metabase provides the visualization layer for SoypeteTech analytics.

## Deployment

```bash
# Deploy with kustomize (part of full stack)
make deploy

# Or deploy just Metabase
kubectl apply -k k8s/metabase/
```

## Accessing Metabase

```bash
# Port forward to local machine
make port-forward-metabase

# Open http://localhost:3000
```

## Initial Setup

On first access:

1. **Create Admin Account**
   - Use email from 1Password item `eleduck-metabase`
   - Set a secure password

2. **Add Analytics Database**
   - Click "Add a database"
   - Database type: PostgreSQL
   - Host: `postgres.eleduck-analytics.svc.cluster.local`
   - Port: `5432`
   - Database name: `analytics`
   - Username: (from postgres-credentials secret)
   - Password: (from postgres-credentials secret)
   - Schema filter: `analytics` (only show star schema tables)

3. **Verify Connection**
   - Browse the database
   - You should see dimension and fact tables

## Analytics Database Structure

### Dimensions
| Table | Description | Key Columns |
|-------|-------------|-------------|
| `dim_date` | Date dimension | date_key, full_date, fiscal_year |
| `dim_platform` | Platform master | platform_key, platform_name |
| `dim_content` | Unified content | content_key, title, platform |
| `dim_repository` | GitHub repos | repo_key, repo_name |

### Facts
| Table | Description | Key Metrics |
|-------|-------------|-------------|
| `fact_daily_engagement` | Content performance | views, likes, comments |
| `fact_revenue` | Stripe transactions | amount_dollars |
| `fact_github_activity` | Code activity | commits, prs_opened |

## Suggested Starter Dashboards

### 1. Content Overview
Questions to create:
- Total views by platform (last 30 days)
- Top 10 content by engagement
- Views trend over time
- Platform comparison pie chart

### 2. Revenue Dashboard
Questions to create:
- Monthly revenue trend
- Revenue by product
- Customer count over time
- Average transaction value

### 3. GitHub Activity
Questions to create:
- Commits per week by repository
- PR merge rate
- Issue resolution time
- Contributor activity

### 4. Cross-Platform Performance
Questions to create:
- Engagement rate by platform
- Content publish frequency
- Audience growth trends

## Creating Questions

### Using the Query Builder

1. Click "New" → "Question"
2. Select "Analytics" database
3. Choose a fact table (e.g., `fact_daily_engagement`)
4. Add summarizations (Sum, Average, Count)
5. Group by dimensions (date, platform, content)
6. Add filters
7. Choose visualization type
8. Save to a collection

### Using SQL (for power users)

Example: Top content by views last 30 days

```sql
SELECT
    c.title,
    c.platform,
    c.url,
    SUM(f.views) as total_views,
    SUM(f.likes) as total_likes,
    SUM(f.comments) as total_comments
FROM analytics.fact_daily_engagement f
JOIN analytics.dim_content c ON f.content_key = c.content_key
JOIN analytics.dim_date d ON f.date_key = d.date_key
WHERE d.full_date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY c.content_key, c.title, c.platform, c.url
ORDER BY total_views DESC
LIMIT 20;
```

Example: Monthly revenue with YoY comparison

```sql
WITH monthly_revenue AS (
    SELECT
        d.year,
        d.month,
        d.year_month,
        SUM(f.amount_dollars) as revenue
    FROM analytics.fact_revenue f
    JOIN analytics.dim_date d ON f.date_key = d.date_key
    GROUP BY d.year, d.month, d.year_month
)
SELECT
    current_year.year_month,
    current_year.revenue as current_revenue,
    last_year.revenue as prior_year_revenue,
    ROUND((current_year.revenue - last_year.revenue) / NULLIF(last_year.revenue, 0) * 100, 1) as yoy_growth_pct
FROM monthly_revenue current_year
LEFT JOIN monthly_revenue last_year
    ON current_year.year = last_year.year + 1
    AND current_year.month = last_year.month
ORDER BY current_year.year_month DESC;
```

## Using pg_duckdb for Complex Queries

For heavy analytical queries, you can leverage pg_duckdb:

```sql
-- Enable DuckDB execution for this query
SET duckdb.execution = true;

-- Run your analytical query
SELECT
    platform,
    DATE_TRUNC('week', d.full_date) as week,
    SUM(views) as views,
    SUM(likes) as likes,
    AVG(avg_view_duration_seconds) as avg_duration
FROM analytics.fact_daily_engagement f
JOIN analytics.dim_date d ON f.date_key = d.date_key
GROUP BY 1, 2
ORDER BY 1, 2;

-- Reset to PostgreSQL execution
SET duckdb.execution = false;
```

## Dashboard Export/Import

To version control dashboards:

### Export
```bash
# Get dashboard ID from URL (e.g., /dashboard/1)
curl -X GET "http://localhost:3000/api/dashboard/1" \
  -H "X-Metabase-Session: YOUR_SESSION_TOKEN" \
  > metabase/dashboards/content-overview.json
```

### Import
```bash
# Import dashboard from JSON
curl -X POST "http://localhost:3000/api/dashboard" \
  -H "Content-Type: application/json" \
  -H "X-Metabase-Session: YOUR_SESSION_TOKEN" \
  -d @metabase/dashboards/content-overview.json
```

## Embedding (Future)

Metabase supports embedding dashboards in other applications:

1. Enable embedding in Admin → Settings → Embedding
2. Generate signed embed URLs
3. Embed in your website or app

## Alerting

Set up alerts for important metrics:

1. Create a question (e.g., "Revenue today")
2. Click bell icon → "Create alert"
3. Set conditions and recipients
4. Alerts require email configuration (SMTP)

## Troubleshooting

### Connection Issues
```bash
# Check Metabase can reach PostgreSQL
kubectl exec -it deploy/metabase -n eleduck-analytics -- \
  nc -zv postgres.eleduck-analytics.svc.cluster.local 5432
```

### Slow Queries
- Check if query should use pg_duckdb
- Add database indexes if needed
- Review DBT incremental strategies

### Memory Issues
If Metabase OOMs, increase limits in deployment.yaml:
```yaml
resources:
  limits:
    memory: "4Gi"
```

### Logs
```bash
kubectl logs -f deploy/metabase -n eleduck-analytics
```
