package socialmedia

import (
	"context"
	"time"
)

// Platform represents a social media platform
type Platform string

const (
	PlatformTwitter  Platform = "twitter"
	PlatformTikTok   Platform = "tiktok"
	PlatformTwitch   Platform = "twitch"
	PlatformLinkedIn Platform = "linkedin"
	PlatformYouTube  Platform = "youtube" // For social media content, not podcasts
)

// Account represents a social media account/profile
type Account struct {
	ID                int64
	Platform          Platform
	PlatformAccountID string
	Username          string
	DisplayName       string
	Description       string
	ProfileImageURL   string
	Verified          bool
	AccountCreatedAt  *time.Time
	RawData           map[string]interface{}
}

// Post represents a social media post/video/stream
type Post struct {
	ID             int64
	AccountID      int64
	PlatformPostID string
	ContentType    string // 'tweet', 'retweet', 'tiktok', 'linkedin_post', 'twitch_stream', 'youtube_video'
	Title          string
	ContentText    string
	MediaURLs      []string
	Hashtags       []string
	Mentions       []string
	URL            string
	DurationSeconds *int
	IsLive         bool
	Language       string
	PublishedAt    time.Time
	RawData        map[string]interface{}
}

// PostMetrics represents metrics for a single post on a given date
type PostMetrics struct {
	PostID                    int64
	MetricDate                time.Time
	Views                     int64
	Impressions               int64
	Reach                     int64
	Likes                     int64
	Dislikes                  int64
	CommentsCount             int64
	Shares                    int64
	Saves                     int64
	Clicks                    int64

	// Twitter/X specific
	Retweets                  int64
	QuoteTweets               int64
	Replies                   int64

	// TikTok specific
	TotalTimeWatchedSeconds   int64
	AverageWatchTimeSeconds   int
	CompletionRate            *float64

	// Twitch specific
	UniqueViewers             int64
	MaxViewers                int64
	AverageViewers            int
	StreamDurationSeconds     int
	ChatMessages              int64

	// YouTube specific
	WatchTimeMinutes          int64
	AverageViewDurationSeconds int
	SubscribersGained         int
	SubscribersLost           int

	// LinkedIn specific
	Engagements               int64

	// Common
	FollowersGained           int
	FollowersLost             int
	TopCountries              map[string]interface{}
	TopCities                 map[string]interface{}
	DemographicBreakdown      map[string]interface{}
	DeviceBreakdown           map[string]interface{}
	TrafficSources            map[string]interface{}
	RawData                   map[string]interface{}
}

// AccountMetrics represents aggregate metrics for an account
type AccountMetrics struct {
	AccountID                int64
	MetricDate               time.Time
	FollowersTotal           *int64
	FollowersGained          int
	FollowersLost            int
	FollowingTotal           *int64

	// Aggregate engagement
	TotalImpressions         int64
	TotalViews               int64
	TotalLikes               int64
	TotalComments            int64
	TotalShares              int64
	TotalSaves               int64
	TotalClicks              int64

	// Twitter/X specific
	TotalRetweets            int64
	TotalQuoteTweets         int64
	TotalReplies             int64
	TweetsPosted             int

	// TikTok specific
	TotalWatchTimeSeconds    int64
	VideosPosted             int

	// Twitch specific
	TotalStreamTimeSeconds   int64
	TotalUniqueViewers       int64
	StreamsCount             int
	SubscribersTotal         *int64 // Paid subscribers
	BitsTotal                int64

	// LinkedIn specific
	TotalEngagements         int64
	PostsPosted              int
	ProfileViews             int64

	// YouTube specific
	YouTubeSubscribersTotal  *int64
	TotalWatchTimeMinutes    int64
	YouTubeVideosPosted      int

	TopCountries             map[string]interface{}
	TopCities                map[string]interface{}
	RawData                  map[string]interface{}
}

// Comment represents a comment on a post
type Comment struct {
	PostID            int64
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
	Platform         Platform
	RunStartedAt     time.Time
	RunCompletedAt   *time.Time
	Status           string
	PostsProcessed   int
	MetricsCollected int
	ErrorMessage     *string
}

// SocialMediaScraper is the interface that all social media platform scrapers must implement
type SocialMediaScraper interface {
	// GetPlatform returns the platform this scraper handles
	GetPlatform() Platform

	// FetchAccountInfo fetches basic account information
	FetchAccountInfo(ctx context.Context, username string) (*Account, error)

	// FetchPosts fetches recent posts/content for an account
	FetchPosts(ctx context.Context, account *Account, startDate, endDate time.Time) ([]*Post, error)

	// FetchPostMetrics fetches metrics for a specific post and date range
	FetchPostMetrics(ctx context.Context, post *Post, startDate, endDate time.Time) ([]*PostMetrics, error)

	// FetchAccountMetrics fetches aggregate metrics for the account
	FetchAccountMetrics(ctx context.Context, account *Account, startDate, endDate time.Time) ([]*AccountMetrics, error)

	// FetchComments fetches comments for a post (if supported by platform)
	FetchComments(ctx context.Context, post *Post) ([]*Comment, error)
}
