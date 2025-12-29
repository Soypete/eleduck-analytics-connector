-- Sample Analytics Queries for eleduck-analytics

-- ============================================
-- 1. Cross-Platform Content Performance
-- ============================================
-- Top performing content across all platforms by total engagement
with content_performance as (
    select
        c.content_key,
        c.platform,
        c.title,
        c.published_at,
        c.url,
        coalesce(p.total_views, 0) as total_views,
        coalesce(p.total_likes, 0) as total_likes,
        coalesce(p.total_comments, 0) as total_comments,
        coalesce(p.total_shares, 0) as total_shares,
        coalesce(p.total_likes + p.total_comments + p.total_shares, 0) as total_engagement
    from {{ ref('dim_content') }} c
    left join {{ ref('fact_content_performance') }} p on c.content_key = p.content_key
)
select * from content_performance
order by total_engagement desc
limit 20;


-- ============================================
-- 2. Daily Engagement Trends by Platform
-- ============================================
-- 30-day rolling engagement by platform
select
    d.full_date,
    e.platform,
    sum(e.views) as daily_views,
    sum(e.likes + e.comments + e.shares) as daily_engagement,
    avg(sum(e.views)) over (
        partition by e.platform
        order by d.full_date
        rows between 6 preceding and current row
    ) as views_7day_avg
from {{ ref('fact_daily_engagement') }} e
join {{ ref('dim_date') }} d on e.date_key = d.date_key
where d.full_date >= current_date - interval '30 days'
group by 1, 2
order by 1, 2;


-- ============================================
-- 3. Revenue Analysis
-- ============================================
-- Monthly revenue summary
select
    d.year,
    d.month,
    d.month_name,
    count(distinct r.charge_id) as transactions,
    sum(r.amount_dollars) as total_revenue,
    avg(r.amount_dollars) as avg_transaction_value,
    count(case when r.is_refunded then 1 end) as refunds
from {{ ref('fact_revenue') }} r
join {{ ref('dim_date') }} d on r.date_key = d.date_key
group by 1, 2, 3
order by 1 desc, 2 desc;


-- ============================================
-- 4. GitHub Repository Activity
-- ============================================
-- Repository activity over the last 30 days
select
    r.repo_name,
    r.primary_language,
    sum(g.commits) as total_commits,
    sum(g.lines_added) as lines_added,
    sum(g.lines_deleted) as lines_deleted,
    sum(g.prs_opened) as prs_opened,
    sum(g.prs_merged) as prs_merged,
    sum(g.issues_opened) as issues_opened,
    sum(g.issues_closed) as issues_closed,
    count(distinct case when g.commits > 0 then g.date_key end) as active_days
from {{ ref('fact_github_activity') }} g
join {{ ref('dim_repository') }} r on g.repo_key = r.repo_key
join {{ ref('dim_date') }} d on g.date_key = d.date_key
where d.full_date >= current_date - interval '30 days'
group by 1, 2
order by total_commits desc;


-- ============================================
-- 5. Platform Comparison Dashboard
-- ============================================
-- Summary metrics by platform
select
    p.platform_name,
    p.platform_category,
    count(distinct c.content_key) as content_count,
    sum(e.views) as total_views,
    sum(e.likes + e.comments + e.shares) as total_engagement,
    {{ safe_divide('sum(e.likes + e.comments + e.shares)', 'sum(e.views)') }} * 100 as engagement_rate_pct
from {{ ref('dim_platform') }} p
left join {{ ref('dim_content') }} c on p.platform_key = c.platform_key
left join {{ ref('fact_daily_engagement') }} e on c.content_key = e.content_key
group by 1, 2
order by total_views desc;


-- ============================================
-- 6. Fiscal Year Revenue Report
-- ============================================
-- Revenue by fiscal quarter
select
    d.fiscal_year,
    d.fiscal_quarter,
    d.fiscal_year_quarter,
    sum(r.amount_dollars) as quarterly_revenue,
    sum(sum(r.amount_dollars)) over (
        partition by d.fiscal_year
        order by d.fiscal_quarter
    ) as ytd_revenue
from {{ ref('fact_revenue') }} r
join {{ ref('dim_date') }} d on r.date_key = d.date_key
group by 1, 2, 3
order by 1, 2;


-- ============================================
-- 7. Content Publishing Cadence
-- ============================================
-- Content published per week by platform
select
    d.year,
    d.week_of_year,
    c.platform,
    count(*) as content_published
from {{ ref('dim_content') }} c
join {{ ref('dim_date') }} d on c.published_date_key = d.date_key
where d.full_date >= current_date - interval '90 days'
group by 1, 2, 3
order by 1 desc, 2 desc, 4 desc;
