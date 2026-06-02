-- +goose Up
-- Create social media metrics tables for Twitter/X, TikTok, Twitch, LinkedIn

-- Social media accounts table
CREATE TABLE IF NOT EXISTS raw.social_media_accounts (
    id BIGSERIAL PRIMARY KEY,
    platform VARCHAR(50) NOT NULL, -- 'twitter', 'tiktok', 'twitch', 'linkedin', 'youtube'
    platform_account_id VARCHAR(255) NOT NULL, -- External ID from the platform
    username VARCHAR(255),
    display_name VARCHAR(255),
    description TEXT,
    profile_image_url TEXT,
    verified BOOLEAN DEFAULT FALSE,
    account_created_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(platform, platform_account_id)
);

CREATE INDEX idx_social_accounts_platform ON raw.social_media_accounts(platform);
CREATE INDEX idx_social_accounts_username ON raw.social_media_accounts(username);

-- Social media posts/content table (tweets, TikToks, LinkedIn posts, Twitch streams, YouTube videos)
CREATE TABLE IF NOT EXISTS raw.social_media_posts (
    id BIGSERIAL PRIMARY KEY,
    account_id BIGINT NOT NULL REFERENCES raw.social_media_accounts(id) ON DELETE CASCADE,
    platform_post_id VARCHAR(255) NOT NULL, -- External post/video/stream ID
    content_type VARCHAR(50), -- 'tweet', 'retweet', 'tiktok', 'linkedin_post', 'twitch_stream', 'youtube_video'
    title VARCHAR(1000),
    content_text TEXT,
    media_urls JSONB, -- Array of media URLs (images, videos)
    hashtags JSONB, -- Array of hashtags
    mentions JSONB, -- Array of mentioned users
    url TEXT, -- Link to the post
    duration_seconds INTEGER, -- For videos/streams
    is_live BOOLEAN DEFAULT FALSE, -- For Twitch streams
    language VARCHAR(10),
    published_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(account_id, platform_post_id)
);

CREATE INDEX idx_social_posts_account_id ON raw.social_media_posts(account_id);
CREATE INDEX idx_social_posts_published_at ON raw.social_media_posts(published_at);
CREATE INDEX idx_social_posts_content_type ON raw.social_media_posts(content_type);
CREATE INDEX idx_social_posts_platform_post_id ON raw.social_media_posts(platform_post_id);

-- Daily post metrics (per post/video/stream)
CREATE TABLE IF NOT EXISTS raw.social_media_post_metrics (
    id BIGSERIAL PRIMARY KEY,
    post_id BIGINT NOT NULL REFERENCES raw.social_media_posts(id) ON DELETE CASCADE,
    metric_date DATE NOT NULL,

    -- Universal engagement metrics
    views BIGINT DEFAULT 0,
    impressions BIGINT DEFAULT 0, -- Twitter/X, LinkedIn
    reach BIGINT DEFAULT 0, -- TikTok, LinkedIn
    likes BIGINT DEFAULT 0,
    dislikes BIGINT DEFAULT 0, -- YouTube
    comments_count BIGINT DEFAULT 0,
    shares BIGINT DEFAULT 0,
    saves BIGINT DEFAULT 0, -- TikTok, LinkedIn
    clicks BIGINT DEFAULT 0, -- LinkedIn, Twitter

    -- Platform-specific metrics
    retweets BIGINT DEFAULT 0, -- Twitter/X
    quote_tweets BIGINT DEFAULT 0, -- Twitter/X
    replies BIGINT DEFAULT 0, -- Twitter/X

    -- TikTok specific
    total_time_watched_seconds BIGINT DEFAULT 0,
    average_watch_time_seconds INTEGER DEFAULT 0,
    completion_rate DECIMAL(5,2), -- Percentage (0-100)

    -- Twitch specific
    unique_viewers BIGINT DEFAULT 0,
    max_viewers BIGINT DEFAULT 0,
    average_viewers INTEGER DEFAULT 0,
    stream_duration_seconds INTEGER DEFAULT 0,
    chat_messages BIGINT DEFAULT 0,

    -- YouTube specific (for social media videos, not podcasts)
    watch_time_minutes BIGINT DEFAULT 0,
    average_view_duration_seconds INTEGER DEFAULT 0,
    subscribers_gained INTEGER DEFAULT 0,
    subscribers_lost INTEGER DEFAULT 0,

    -- LinkedIn specific
    engagements BIGINT DEFAULT 0, -- Total engagement (likes + comments + shares)

    -- Follower changes (for all platforms)
    followers_gained INTEGER DEFAULT 0,
    followers_lost INTEGER DEFAULT 0,

    -- Geographic and demographic data
    top_countries JSONB, -- [{"country": "US", "count": 1000}, ...]
    top_cities JSONB, -- [{"city": "New York", "count": 500}, ...]
    demographic_breakdown JSONB, -- Age, gender, etc.
    device_breakdown JSONB, -- {"mobile": 1000, "desktop": 500}

    -- Traffic sources
    traffic_sources JSONB, -- {"organic": 500, "recommended": 300, "search": 200}

    -- Raw platform response (for debugging/additional fields)
    raw_data JSONB,

    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    UNIQUE(post_id, metric_date)
);

CREATE INDEX idx_social_post_metrics_post_id ON raw.social_media_post_metrics(post_id);
CREATE INDEX idx_social_post_metrics_date ON raw.social_media_post_metrics(metric_date);
CREATE INDEX idx_social_post_metrics_post_date ON raw.social_media_post_metrics(post_id, metric_date);

-- Account-level daily metrics (aggregated across all posts)
CREATE TABLE IF NOT EXISTS raw.social_media_account_metrics (
    id BIGSERIAL PRIMARY KEY,
    account_id BIGINT NOT NULL REFERENCES raw.social_media_accounts(id) ON DELETE CASCADE,
    metric_date DATE NOT NULL,

    -- Follower/Subscriber metrics
    followers_total BIGINT,
    followers_gained INTEGER DEFAULT 0,
    followers_lost INTEGER DEFAULT 0,
    following_total BIGINT, -- Who the account follows

    -- Aggregate engagement metrics
    total_impressions BIGINT DEFAULT 0,
    total_views BIGINT DEFAULT 0,
    total_likes BIGINT DEFAULT 0,
    total_comments BIGINT DEFAULT 0,
    total_shares BIGINT DEFAULT 0,
    total_saves BIGINT DEFAULT 0,
    total_clicks BIGINT DEFAULT 0,

    -- Twitter/X specific
    total_retweets BIGINT DEFAULT 0,
    total_quote_tweets BIGINT DEFAULT 0,
    total_replies BIGINT DEFAULT 0,
    tweets_posted INTEGER DEFAULT 0,

    -- TikTok specific
    total_watch_time_seconds BIGINT DEFAULT 0,
    videos_posted INTEGER DEFAULT 0,

    -- Twitch specific
    total_stream_time_seconds BIGINT DEFAULT 0,
    total_unique_viewers BIGINT DEFAULT 0,
    streams_count INTEGER DEFAULT 0,
    subscribers_total BIGINT, -- Twitch paid subscribers
    bits_total BIGINT, -- Twitch bits received

    -- LinkedIn specific
    total_engagements BIGINT DEFAULT 0,
    posts_posted INTEGER DEFAULT 0,
    profile_views BIGINT DEFAULT 0,

    -- YouTube specific (for channel, not individual videos)
    subscribers_total BIGINT,
    total_watch_time_minutes BIGINT DEFAULT 0,
    videos_posted INTEGER DEFAULT 0,

    -- Geographic data
    top_countries JSONB,
    top_cities JSONB,

    -- Raw platform response
    raw_data JSONB,

    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    UNIQUE(account_id, metric_date)
);

CREATE INDEX idx_social_account_metrics_account_id ON raw.social_media_account_metrics(account_id);
CREATE INDEX idx_social_account_metrics_date ON raw.social_media_account_metrics(metric_date);
CREATE INDEX idx_social_account_metrics_account_date ON raw.social_media_account_metrics(account_id, metric_date);

-- Comments table (for platforms that provide detailed comment data)
CREATE TABLE IF NOT EXISTS raw.social_media_comments (
    id BIGSERIAL PRIMARY KEY,
    post_id BIGINT NOT NULL REFERENCES raw.social_media_posts(id) ON DELETE CASCADE,
    platform_comment_id VARCHAR(255) NOT NULL,
    author_name VARCHAR(255),
    author_id VARCHAR(255),
    comment_text TEXT,
    likes_count INTEGER DEFAULT 0,
    reply_count INTEGER DEFAULT 0,
    parent_comment_id BIGINT REFERENCES raw.social_media_comments(id),
    published_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(post_id, platform_comment_id)
);

CREATE INDEX idx_social_comments_post_id ON raw.social_media_comments(post_id);
CREATE INDEX idx_social_comments_published_at ON raw.social_media_comments(published_at);
CREATE INDEX idx_social_comments_parent_id ON raw.social_media_comments(parent_comment_id);

-- Scraper runs tracking (for monitoring and debugging)
CREATE TABLE IF NOT EXISTS raw.social_media_scraper_runs (
    id BIGSERIAL PRIMARY KEY,
    platform VARCHAR(50) NOT NULL,
    run_started_at TIMESTAMP WITH TIME ZONE NOT NULL,
    run_completed_at TIMESTAMP WITH TIME ZONE,
    status VARCHAR(20) NOT NULL, -- 'running', 'completed', 'failed'
    posts_processed INTEGER DEFAULT 0,
    metrics_collected INTEGER DEFAULT 0,
    error_message TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_social_scraper_runs_platform ON raw.social_media_scraper_runs(platform);
CREATE INDEX idx_social_scraper_runs_started_at ON raw.social_media_scraper_runs(run_started_at);
CREATE INDEX idx_social_scraper_runs_status ON raw.social_media_scraper_runs(status);

-- Staging views for data quality and transformation
CREATE VIEW staging.social_media_metrics_latest AS
SELECT
    sma.platform,
    sma.username,
    sma.display_name,
    smp.content_type,
    smp.title,
    smp.content_text,
    smp.published_at,
    smpm.metric_date,
    smpm.views,
    smpm.impressions,
    smpm.likes,
    smpm.comments_count,
    smpm.shares,
    smpm.top_countries,
    smpm.top_cities
FROM raw.social_media_post_metrics smpm
JOIN raw.social_media_posts smp ON smpm.post_id = smp.id
JOIN raw.social_media_accounts sma ON smp.account_id = sma.id
WHERE smpm.metric_date >= CURRENT_DATE - INTERVAL '30 days';

-- Analytics view for cross-platform comparison
CREATE VIEW analytics.social_media_performance_summary AS
SELECT
    sma.platform,
    sma.username,
    sma.display_name,
    COUNT(DISTINCT smp.id) as total_posts,
    SUM(smpm.views) as total_views,
    SUM(smpm.impressions) as total_impressions,
    SUM(smpm.likes) as total_likes,
    SUM(smpm.comments_count) as total_comments,
    SUM(smpm.shares) as total_shares,
    AVG(smpm.completion_rate) as avg_completion_rate,
    MAX(smam.followers_total) as latest_followers,
    MAX(smam.subscribers_total) as latest_subscribers
FROM raw.social_media_accounts sma
LEFT JOIN raw.social_media_posts smp ON sma.id = smp.account_id
LEFT JOIN raw.social_media_post_metrics smpm ON smp.id = smpm.post_id
LEFT JOIN raw.social_media_account_metrics smam ON sma.id = smam.account_id
WHERE smpm.metric_date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY sma.platform, sma.username, sma.display_name;

-- +goose Down
DROP VIEW IF EXISTS analytics.social_media_performance_summary;
DROP VIEW IF EXISTS staging.social_media_metrics_latest;
DROP TABLE IF EXISTS raw.social_media_scraper_runs;
DROP TABLE IF EXISTS raw.social_media_comments;
DROP TABLE IF EXISTS raw.social_media_account_metrics;
DROP TABLE IF EXISTS raw.social_media_post_metrics;
DROP TABLE IF EXISTS raw.social_media_posts;
DROP TABLE IF EXISTS raw.social_media_accounts;
