package scrapers

import (
	"context"
	"time"
)

// Platform represents a podcast/video platform
type Platform string

const (
	PlatformApplePodcasts Platform = "apple_podcasts"
	PlatformSpotify       Platform = "spotify"
	PlatformAmazonMusic   Platform = "amazon_music"
	PlatformYouTube       Platform = "youtube"
)

// Podcast represents a podcast show
type Podcast struct {
	ID          int64
	ShowName    string
	Platform    Platform
	PlatformID  string
	Description string
	Author      string
	Categories  map[string]interface{}
	Language    string
	RawData     map[string]interface{}
}

// Episode represents a podcast episode
type Episode struct {
	ID                int64
	PodcastID         int64
	EpisodeTitle      string
	PlatformEpisodeID string
	Description       string
	DurationSeconds   int
	PublishDate       time.Time
	SeasonNumber      *int
	EpisodeNumber     *int
}

// EpisodeMetrics represents metrics for a single episode on a given date
type EpisodeMetrics struct {
	EpisodeID                int64
	MetricDate               time.Time
	Plays                    int64
	Listeners                int64
	EngagedListeners         int64
	Views                    int64
	Likes                    int64
	Dislikes                 int64
	CommentsCount            int64
	Shares                   int64
	WatchTimeMinutes         int64
	AverageViewDuration      int
	SubscribersGained        int
	SubscribersLost          int
	Downloads                int64
	Streams                  int64
	CompletionRate           *float64
	AverageListenTime        *int
	FollowersTotal           *int64
	FollowersGained          int
	FollowersLost            int
	TopCountries             map[string]interface{}
	TopCities                map[string]interface{}
	DeviceBreakdown          map[string]interface{}
	RawData                  map[string]interface{}
}

// ShowMetrics represents aggregate metrics for the entire show
type ShowMetrics struct {
	PodcastID              int64
	MetricDate             time.Time
	TotalPlays             int64
	TotalListeners         int64
	TotalEngagedListeners  int64
	TotalViews             int64
	TotalDownloads         int64
	FollowersTotal         *int64
	FollowersGained        int
	FollowersLost          int
	SubscribersTotal       *int64
	SubscribersGained      int
	SubscribersLost        int
	AverageCompletionRate  *float64
	TotalComments          int64
	TotalLikes             int64
	TotalShares            int64
	TopCountries           map[string]interface{}
	TopCities              map[string]interface{}
	RawData                map[string]interface{}
}

// Comment represents a comment on an episode
type Comment struct {
	EpisodeID         int64
	PlatformCommentID string
	AuthorName        string
	AuthorID          string
	CommentText       string
	LikesCount        int
	ReplyCount        int
	ParentCommentID   *int64
	PublishedAt       time.Time
}

// ScraperRun tracks a scraper execution
type ScraperRun struct {
	Platform          Platform
	RunStartedAt      time.Time
	RunCompletedAt    *time.Time
	Status            string
	EpisodesProcessed int
	MetricsCollected  int
	ErrorMessage      *string
}

// Scraper is the interface that all platform scrapers must implement
type Scraper interface {
	// GetPlatform returns the platform this scraper handles
	GetPlatform() Platform

	// FetchPodcastInfo fetches basic podcast information
	FetchPodcastInfo(ctx context.Context, showName string) (*Podcast, error)

	// FetchEpisodes fetches all episodes for a podcast
	FetchEpisodes(ctx context.Context, podcast *Podcast) ([]*Episode, error)

	// FetchEpisodeMetrics fetches metrics for a specific episode and date range
	FetchEpisodeMetrics(ctx context.Context, episode *Episode, startDate, endDate time.Time) ([]*EpisodeMetrics, error)

	// FetchShowMetrics fetches aggregate metrics for the show
	FetchShowMetrics(ctx context.Context, podcast *Podcast, startDate, endDate time.Time) ([]*ShowMetrics, error)

	// FetchComments fetches comments for an episode (if supported by platform)
	FetchComments(ctx context.Context, episode *Episode) ([]*Comment, error)
}
