package repository

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"time"

	"github.com/soypete/eleduck-analytics-connector/internal/scrapers"
)

// PodcastRepository handles database operations for podcast metrics
type PodcastRepository struct {
	db *sql.DB
}

// NewPodcastRepository creates a new podcast repository
func NewPodcastRepository(db *sql.DB) *PodcastRepository {
	return &PodcastRepository{db: db}
}

// UpsertPodcast inserts or updates a podcast
func (r *PodcastRepository) UpsertPodcast(ctx context.Context, podcast *scrapers.Podcast) (int64, error) {
	categoriesJSON, err := json.Marshal(podcast.Categories)
	if err != nil {
		return 0, fmt.Errorf("failed to marshal categories: %w", err)
	}

	query := `
		INSERT INTO raw.podcasts (show_name, platform, platform_id, description, author, categories, language, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
		ON CONFLICT (platform, platform_id)
		DO UPDATE SET
			show_name = EXCLUDED.show_name,
			description = EXCLUDED.description,
			author = EXCLUDED.author,
			categories = EXCLUDED.categories,
			language = EXCLUDED.language,
			updated_at = EXCLUDED.updated_at
		RETURNING id
	`

	var id int64
	err = r.db.QueryRowContext(ctx, query,
		podcast.ShowName,
		podcast.Platform,
		podcast.PlatformID,
		podcast.Description,
		podcast.Author,
		categoriesJSON,
		podcast.Language,
		time.Now(),
	).Scan(&id)

	if err != nil {
		return 0, fmt.Errorf("failed to upsert podcast: %w", err)
	}

	return id, nil
}

// UpsertEpisode inserts or updates an episode
func (r *PodcastRepository) UpsertEpisode(ctx context.Context, episode *scrapers.Episode) (int64, error) {
	query := `
		INSERT INTO raw.podcast_episodes (
			podcast_id, episode_title, platform_episode_id, description,
			duration_seconds, publish_date, season_number, episode_number, updated_at
		)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
		ON CONFLICT (podcast_id, platform_episode_id)
		DO UPDATE SET
			episode_title = EXCLUDED.episode_title,
			description = EXCLUDED.description,
			duration_seconds = EXCLUDED.duration_seconds,
			publish_date = EXCLUDED.publish_date,
			season_number = EXCLUDED.season_number,
			episode_number = EXCLUDED.episode_number,
			updated_at = EXCLUDED.updated_at
		RETURNING id
	`

	var id int64
	err := r.db.QueryRowContext(ctx, query,
		episode.PodcastID,
		episode.EpisodeTitle,
		episode.PlatformEpisodeID,
		episode.Description,
		episode.DurationSeconds,
		episode.PublishDate,
		episode.SeasonNumber,
		episode.EpisodeNumber,
		time.Now(),
	).Scan(&id)

	if err != nil {
		return 0, fmt.Errorf("failed to upsert episode: %w", err)
	}

	return id, nil
}

// UpsertEpisodeMetrics inserts or updates episode metrics
func (r *PodcastRepository) UpsertEpisodeMetrics(ctx context.Context, metrics *scrapers.EpisodeMetrics) error {
	topCountriesJSON, _ := json.Marshal(metrics.TopCountries)
	topCitiesJSON, _ := json.Marshal(metrics.TopCities)
	deviceBreakdownJSON, _ := json.Marshal(metrics.DeviceBreakdown)
	rawDataJSON, _ := json.Marshal(metrics.RawData)

	query := `
		INSERT INTO raw.podcast_episode_metrics (
			episode_id, metric_date, plays, listeners, engaged_listeners,
			views, likes, dislikes, comments_count, shares, watch_time_minutes,
			average_view_duration_seconds, subscribers_gained, subscribers_lost,
			downloads, streams, completion_rate, average_listen_time_seconds,
			followers_total, followers_gained, followers_lost,
			top_countries, top_cities, device_breakdown, raw_data, updated_at
		)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $20, $21, $22, $23, $24, $25, $26)
		ON CONFLICT (episode_id, metric_date)
		DO UPDATE SET
			plays = EXCLUDED.plays,
			listeners = EXCLUDED.listeners,
			engaged_listeners = EXCLUDED.engaged_listeners,
			views = EXCLUDED.views,
			likes = EXCLUDED.likes,
			dislikes = EXCLUDED.dislikes,
			comments_count = EXCLUDED.comments_count,
			shares = EXCLUDED.shares,
			watch_time_minutes = EXCLUDED.watch_time_minutes,
			average_view_duration_seconds = EXCLUDED.average_view_duration_seconds,
			subscribers_gained = EXCLUDED.subscribers_gained,
			subscribers_lost = EXCLUDED.subscribers_lost,
			downloads = EXCLUDED.downloads,
			streams = EXCLUDED.streams,
			completion_rate = EXCLUDED.completion_rate,
			average_listen_time_seconds = EXCLUDED.average_listen_time_seconds,
			followers_total = EXCLUDED.followers_total,
			followers_gained = EXCLUDED.followers_gained,
			followers_lost = EXCLUDED.followers_lost,
			top_countries = EXCLUDED.top_countries,
			top_cities = EXCLUDED.top_cities,
			device_breakdown = EXCLUDED.device_breakdown,
			raw_data = EXCLUDED.raw_data,
			updated_at = EXCLUDED.updated_at
	`

	_, err := r.db.ExecContext(ctx, query,
		metrics.EpisodeID,
		metrics.MetricDate,
		metrics.Plays,
		metrics.Listeners,
		metrics.EngagedListeners,
		metrics.Views,
		metrics.Likes,
		metrics.Dislikes,
		metrics.CommentsCount,
		metrics.Shares,
		metrics.WatchTimeMinutes,
		metrics.AverageViewDuration,
		metrics.SubscribersGained,
		metrics.SubscribersLost,
		metrics.Downloads,
		metrics.Streams,
		metrics.CompletionRate,
		metrics.AverageListenTime,
		metrics.FollowersTotal,
		metrics.FollowersGained,
		metrics.FollowersLost,
		topCountriesJSON,
		topCitiesJSON,
		deviceBreakdownJSON,
		rawDataJSON,
		time.Now(),
	)

	if err != nil {
		return fmt.Errorf("failed to upsert episode metrics: %w", err)
	}

	return nil
}

// UpsertShowMetrics inserts or updates show-level metrics
func (r *PodcastRepository) UpsertShowMetrics(ctx context.Context, metrics *scrapers.ShowMetrics) error {
	topCountriesJSON, _ := json.Marshal(metrics.TopCountries)
	topCitiesJSON, _ := json.Marshal(metrics.TopCities)
	rawDataJSON, _ := json.Marshal(metrics.RawData)

	query := `
		INSERT INTO raw.podcast_show_metrics (
			podcast_id, metric_date, total_plays, total_listeners, total_engaged_listeners,
			total_views, total_downloads, followers_total, followers_gained, followers_lost,
			subscribers_total, subscribers_gained, subscribers_lost, average_completion_rate,
			total_comments, total_likes, total_shares, top_countries, top_cities, raw_data, updated_at
		)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $20, $21)
		ON CONFLICT (podcast_id, metric_date)
		DO UPDATE SET
			total_plays = EXCLUDED.total_plays,
			total_listeners = EXCLUDED.total_listeners,
			total_engaged_listeners = EXCLUDED.total_engaged_listeners,
			total_views = EXCLUDED.total_views,
			total_downloads = EXCLUDED.total_downloads,
			followers_total = EXCLUDED.followers_total,
			followers_gained = EXCLUDED.followers_gained,
			followers_lost = EXCLUDED.followers_lost,
			subscribers_total = EXCLUDED.subscribers_total,
			subscribers_gained = EXCLUDED.subscribers_gained,
			subscribers_lost = EXCLUDED.subscribers_lost,
			average_completion_rate = EXCLUDED.average_completion_rate,
			total_comments = EXCLUDED.total_comments,
			total_likes = EXCLUDED.total_likes,
			total_shares = EXCLUDED.total_shares,
			top_countries = EXCLUDED.top_countries,
			top_cities = EXCLUDED.top_cities,
			raw_data = EXCLUDED.raw_data,
			updated_at = EXCLUDED.updated_at
	`

	_, err := r.db.ExecContext(ctx, query,
		metrics.PodcastID,
		metrics.MetricDate,
		metrics.TotalPlays,
		metrics.TotalListeners,
		metrics.TotalEngagedListeners,
		metrics.TotalViews,
		metrics.TotalDownloads,
		metrics.FollowersTotal,
		metrics.FollowersGained,
		metrics.FollowersLost,
		metrics.SubscribersTotal,
		metrics.SubscribersGained,
		metrics.SubscribersLost,
		metrics.AverageCompletionRate,
		metrics.TotalComments,
		metrics.TotalLikes,
		metrics.TotalShares,
		topCountriesJSON,
		topCitiesJSON,
		rawDataJSON,
		time.Now(),
	)

	if err != nil {
		return fmt.Errorf("failed to upsert show metrics: %w", err)
	}

	return nil
}

// InsertComment inserts a comment
func (r *PodcastRepository) InsertComment(ctx context.Context, comment *scrapers.Comment) error {
	query := `
		INSERT INTO raw.podcast_comments (
			episode_id, platform_comment_id, author_name, author_id,
			comment_text, likes_count, reply_count, parent_comment_id, published_at
		)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
		ON CONFLICT (episode_id, platform_comment_id) DO NOTHING
	`

	_, err := r.db.ExecContext(ctx, query,
		comment.EpisodeID,
		comment.PlatformCommentID,
		comment.AuthorName,
		comment.AuthorID,
		comment.CommentText,
		comment.LikesCount,
		comment.ReplyCount,
		comment.ParentCommentID,
		comment.PublishedAt,
	)

	if err != nil {
		return fmt.Errorf("failed to insert comment: %w", err)
	}

	return nil
}

// RecordScraperRun records a scraper run
func (r *PodcastRepository) RecordScraperRun(ctx context.Context, run *scrapers.ScraperRun) (int64, error) {
	query := `
		INSERT INTO raw.podcast_scraper_runs (
			platform, run_started_at, run_completed_at, status,
			episodes_processed, metrics_collected, error_message
		)
		VALUES ($1, $2, $3, $4, $5, $6, $7)
		RETURNING id
	`

	var id int64
	err := r.db.QueryRowContext(ctx, query,
		run.Platform,
		run.RunStartedAt,
		run.RunCompletedAt,
		run.Status,
		run.EpisodesProcessed,
		run.MetricsCollected,
		run.ErrorMessage,
	).Scan(&id)

	if err != nil {
		return 0, fmt.Errorf("failed to record scraper run: %w", err)
	}

	return id, nil
}

// UpdateScraperRun updates a scraper run status
func (r *PodcastRepository) UpdateScraperRun(ctx context.Context, runID int64, run *scrapers.ScraperRun) error {
	query := `
		UPDATE raw.podcast_scraper_runs
		SET run_completed_at = $1,
		    status = $2,
		    episodes_processed = $3,
		    metrics_collected = $4,
		    error_message = $5
		WHERE id = $6
	`

	_, err := r.db.ExecContext(ctx, query,
		run.RunCompletedAt,
		run.Status,
		run.EpisodesProcessed,
		run.MetricsCollected,
		run.ErrorMessage,
		runID,
	)

	if err != nil {
		return fmt.Errorf("failed to update scraper run: %w", err)
	}

	return nil
}
