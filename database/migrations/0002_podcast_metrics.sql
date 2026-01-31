-- +goose Up
-- Create podcast metrics tables for domesticating ai across all platforms

-- Podcasts/Shows table
CREATE TABLE IF NOT EXISTS raw.podcasts (
    id BIGSERIAL PRIMARY KEY,
    show_name VARCHAR(255) NOT NULL,
    platform VARCHAR(50) NOT NULL, -- 'apple_podcasts', 'spotify', 'amazon_music', 'youtube'
    platform_id VARCHAR(255), -- External ID from the platform
    description TEXT,
    author VARCHAR(255),
    categories JSONB,
    language VARCHAR(10),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(platform, platform_id)
);

CREATE INDEX idx_podcasts_platform ON raw.podcasts(platform);
CREATE INDEX idx_podcasts_show_name ON raw.podcasts(show_name);

-- Episodes table
CREATE TABLE IF NOT EXISTS raw.podcast_episodes (
    id BIGSERIAL PRIMARY KEY,
    podcast_id BIGINT NOT NULL REFERENCES raw.podcasts(id) ON DELETE CASCADE,
    episode_title VARCHAR(500) NOT NULL,
    platform_episode_id VARCHAR(255), -- External episode ID from platform
    description TEXT,
    duration_seconds INTEGER,
    publish_date TIMESTAMP WITH TIME ZONE,
    season_number INTEGER,
    episode_number INTEGER,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(podcast_id, platform_episode_id)
);

CREATE INDEX idx_episodes_podcast_id ON raw.podcast_episodes(podcast_id);
CREATE INDEX idx_episodes_publish_date ON raw.podcast_episodes(publish_date);
CREATE INDEX idx_episodes_platform_episode_id ON raw.podcast_episodes(platform_episode_id);

-- Daily episode metrics (aggregated)
CREATE TABLE IF NOT EXISTS raw.podcast_episode_metrics (
    id BIGSERIAL PRIMARY KEY,
    episode_id BIGINT NOT NULL REFERENCES raw.podcast_episodes(id) ON DELETE CASCADE,
    metric_date DATE NOT NULL,

    -- Core metrics (common across platforms)
    plays BIGINT DEFAULT 0,
    listeners BIGINT DEFAULT 0,
    engaged_listeners BIGINT DEFAULT 0, -- Listeners who consumed significant portion

    -- YouTube specific
    views BIGINT DEFAULT 0,
    likes BIGINT DEFAULT 0,
    dislikes BIGINT DEFAULT 0,
    comments_count BIGINT DEFAULT 0,
    shares BIGINT DEFAULT 0,
    watch_time_minutes BIGINT DEFAULT 0,
    average_view_duration_seconds INTEGER DEFAULT 0,
    subscribers_gained INTEGER DEFAULT 0,
    subscribers_lost INTEGER DEFAULT 0,

    -- Podcast specific
    downloads BIGINT DEFAULT 0,
    streams BIGINT DEFAULT 0,
    completion_rate DECIMAL(5,2), -- Percentage (0-100)
    average_listen_time_seconds INTEGER,

    -- Follower/Subscriber changes
    followers_total BIGINT,
    followers_gained INTEGER DEFAULT 0,
    followers_lost INTEGER DEFAULT 0,

    -- Geographic data (stored as JSON for flexibility)
    top_countries JSONB, -- [{"country": "US", "count": 1000}, ...]
    top_cities JSONB, -- [{"city": "New York", "count": 500}, ...]

    -- Device/Platform data
    device_breakdown JSONB, -- {"mobile": 1000, "desktop": 500, "tablet": 200}

    -- Raw platform response (for debugging/additional fields)
    raw_data JSONB,

    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    UNIQUE(episode_id, metric_date)
);

CREATE INDEX idx_episode_metrics_episode_id ON raw.podcast_episode_metrics(episode_id);
CREATE INDEX idx_episode_metrics_date ON raw.podcast_episode_metrics(metric_date);
CREATE INDEX idx_episode_metrics_episode_date ON raw.podcast_episode_metrics(episode_id, metric_date);

-- Show-level daily metrics (aggregated across all episodes)
CREATE TABLE IF NOT EXISTS raw.podcast_show_metrics (
    id BIGSERIAL PRIMARY KEY,
    podcast_id BIGINT NOT NULL REFERENCES raw.podcasts(id) ON DELETE CASCADE,
    metric_date DATE NOT NULL,

    -- Aggregate metrics
    total_plays BIGINT DEFAULT 0,
    total_listeners BIGINT DEFAULT 0,
    total_engaged_listeners BIGINT DEFAULT 0,
    total_views BIGINT DEFAULT 0, -- YouTube
    total_downloads BIGINT DEFAULT 0,

    -- Follower/Subscriber metrics
    followers_total BIGINT,
    followers_gained INTEGER DEFAULT 0,
    followers_lost INTEGER DEFAULT 0,
    subscribers_total BIGINT, -- YouTube
    subscribers_gained INTEGER DEFAULT 0,
    subscribers_lost INTEGER DEFAULT 0,

    -- Engagement metrics
    average_completion_rate DECIMAL(5,2),
    total_comments BIGINT DEFAULT 0,
    total_likes BIGINT DEFAULT 0,
    total_shares BIGINT DEFAULT 0,

    -- Geographic data
    top_countries JSONB,
    top_cities JSONB,

    -- Raw platform response
    raw_data JSONB,

    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    UNIQUE(podcast_id, metric_date)
);

CREATE INDEX idx_show_metrics_podcast_id ON raw.podcast_show_metrics(podcast_id);
CREATE INDEX idx_show_metrics_date ON raw.podcast_show_metrics(metric_date);
CREATE INDEX idx_show_metrics_podcast_date ON raw.podcast_show_metrics(podcast_id, metric_date);

-- Comments table (for platforms that provide detailed comment data like YouTube)
CREATE TABLE IF NOT EXISTS raw.podcast_comments (
    id BIGSERIAL PRIMARY KEY,
    episode_id BIGINT NOT NULL REFERENCES raw.podcast_episodes(id) ON DELETE CASCADE,
    platform_comment_id VARCHAR(255) NOT NULL,
    author_name VARCHAR(255),
    author_id VARCHAR(255),
    comment_text TEXT,
    likes_count INTEGER DEFAULT 0,
    reply_count INTEGER DEFAULT 0,
    parent_comment_id BIGINT REFERENCES raw.podcast_comments(id),
    published_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(episode_id, platform_comment_id)
);

CREATE INDEX idx_comments_episode_id ON raw.podcast_comments(episode_id);
CREATE INDEX idx_comments_published_at ON raw.podcast_comments(published_at);
CREATE INDEX idx_comments_parent_id ON raw.podcast_comments(parent_comment_id);

-- Scraper runs tracking (for monitoring and debugging)
CREATE TABLE IF NOT EXISTS raw.podcast_scraper_runs (
    id BIGSERIAL PRIMARY KEY,
    platform VARCHAR(50) NOT NULL,
    run_started_at TIMESTAMP WITH TIME ZONE NOT NULL,
    run_completed_at TIMESTAMP WITH TIME ZONE,
    status VARCHAR(20) NOT NULL, -- 'running', 'completed', 'failed'
    episodes_processed INTEGER DEFAULT 0,
    metrics_collected INTEGER DEFAULT 0,
    error_message TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_scraper_runs_platform ON raw.podcast_scraper_runs(platform);
CREATE INDEX idx_scraper_runs_started_at ON raw.podcast_scraper_runs(run_started_at);
CREATE INDEX idx_scraper_runs_status ON raw.podcast_scraper_runs(status);

-- Staging views for data quality and transformation
CREATE VIEW staging.podcast_metrics_latest AS
SELECT
    p.show_name,
    p.platform,
    pe.episode_title,
    pe.publish_date,
    pem.metric_date,
    pem.plays,
    pem.listeners,
    pem.engaged_listeners,
    pem.views,
    pem.likes,
    pem.comments_count,
    pem.completion_rate,
    pem.top_countries,
    pem.top_cities
FROM raw.podcast_episode_metrics pem
JOIN raw.podcast_episodes pe ON pem.episode_id = pe.id
JOIN raw.podcasts p ON pe.podcast_id = p.id
WHERE pem.metric_date >= CURRENT_DATE - INTERVAL '30 days';

-- Analytics view for cross-platform comparison
CREATE VIEW analytics.podcast_performance_summary AS
SELECT
    p.show_name,
    p.platform,
    COUNT(DISTINCT pe.id) as total_episodes,
    SUM(pem.plays) as total_plays,
    SUM(pem.listeners) as total_listeners,
    SUM(pem.views) as total_views,
    SUM(pem.downloads) as total_downloads,
    AVG(pem.completion_rate) as avg_completion_rate,
    SUM(pem.comments_count) as total_comments,
    SUM(pem.likes) as total_likes,
    MAX(psm.followers_total) as latest_followers,
    MAX(psm.subscribers_total) as latest_subscribers
FROM raw.podcasts p
LEFT JOIN raw.podcast_episodes pe ON p.id = pe.podcast_id
LEFT JOIN raw.podcast_episode_metrics pem ON pe.id = pem.episode_id
LEFT JOIN raw.podcast_show_metrics psm ON p.id = psm.podcast_id
WHERE pem.metric_date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY p.show_name, p.platform;

-- +goose Down
DROP VIEW IF EXISTS analytics.podcast_performance_summary;
DROP VIEW IF EXISTS staging.podcast_metrics_latest;
DROP TABLE IF EXISTS raw.podcast_scraper_runs;
DROP TABLE IF EXISTS raw.podcast_comments;
DROP TABLE IF EXISTS raw.podcast_show_metrics;
DROP TABLE IF EXISTS raw.podcast_episode_metrics;
DROP TABLE IF EXISTS raw.podcast_episodes;
DROP TABLE IF EXISTS raw.podcasts;
