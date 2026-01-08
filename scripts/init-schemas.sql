-- Initialize database schemas for eleduck-analytics
-- This script is also embedded in the ConfigMap but kept here for reference

-- Create schemas for data warehouse layers
CREATE SCHEMA IF NOT EXISTS raw;
CREATE SCHEMA IF NOT EXISTS staging;
CREATE SCHEMA IF NOT EXISTS analytics;

-- Grant usage to the main user
GRANT ALL ON SCHEMA raw TO CURRENT_USER;
GRANT ALL ON SCHEMA staging TO CURRENT_USER;
GRANT ALL ON SCHEMA analytics TO CURRENT_USER;

-- Set default search path
ALTER DATABASE eleduck SET search_path TO analytics, staging, raw, public;

--------------------------------------------------------------------------------
-- RAW LAYER: Landing tables for Airbyte data
-- These tables are created by Airbyte but we define them for reference
--------------------------------------------------------------------------------

-- Spotify for Creators: Episode metadata
CREATE TABLE IF NOT EXISTS raw.spotify_episodes (
    id VARCHAR(255) PRIMARY KEY,
    name VARCHAR(500),
    description TEXT,
    release_date DATE,
    duration_ms INTEGER,
    explicit BOOLEAN,
    uri VARCHAR(500),
    external_urls JSONB,
    _airbyte_extracted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Spotify for Creators: Daily episode performance
CREATE TABLE IF NOT EXISTS raw.spotify_episode_performance (
    episode_id VARCHAR(255) NOT NULL,
    date DATE NOT NULL,
    starts INTEGER,
    streams INTEGER,
    listeners INTEGER,
    avg_listen_seconds NUMERIC,
    _airbyte_extracted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (episode_id, date)
);

-- Spotify for Creators: Show-level stats
CREATE TABLE IF NOT EXISTS raw.spotify_show_stats (
    date DATE PRIMARY KEY,
    total_streams BIGINT,
    followers INTEGER,
    total_listeners BIGINT,
    _airbyte_extracted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- YouTube: Video metadata
CREATE TABLE IF NOT EXISTS raw.youtube_videos (
    id VARCHAR(50) PRIMARY KEY,
    snippet JSONB,
    content_details JSONB,
    _airbyte_extracted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- YouTube: Daily video stats
CREATE TABLE IF NOT EXISTS raw.youtube_daily_stats (
    video_id VARCHAR(50) NOT NULL,
    date DATE NOT NULL,
    views INTEGER,
    watch_time_minutes NUMERIC,
    average_view_duration NUMERIC,
    likes INTEGER,
    comments INTEGER,
    _airbyte_extracted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (video_id, date)
);

-- Create indexes for common query patterns
CREATE INDEX IF NOT EXISTS idx_spotify_perf_date ON raw.spotify_episode_performance(date);
CREATE INDEX IF NOT EXISTS idx_youtube_stats_date ON raw.youtube_daily_stats(date);
