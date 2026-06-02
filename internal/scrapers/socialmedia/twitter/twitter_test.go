package twitter

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/soypete/eleduck-analytics-connector/internal/scrapers/socialmedia"
)

func TestNewScraper(t *testing.T) {
	tests := []struct {
		name    string
		config  Config
		wantErr bool
	}{
		{
			name: "valid config with bearer token",
			config: Config{
				BearerToken: "test-bearer-token",
			},
			wantErr: false,
		},
		{
			name: "valid config with OAuth",
			config: Config{
				AccessToken: "test-access-token",
			},
			wantErr: false,
		},
		{
			name:    "invalid config - no credentials",
			config:  Config{},
			wantErr: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			scraper, err := NewScraper(tt.config)
			if (err != nil) != tt.wantErr {
				t.Errorf("NewScraper() error = %v, wantErr %v", err, tt.wantErr)
				return
			}
			if !tt.wantErr && scraper == nil {
				t.Error("NewScraper() returned nil scraper")
			}
		})
	}
}

func TestTwitterScraper_GetPlatform(t *testing.T) {
	scraper := &TwitterScraper{}
	if got := scraper.GetPlatform(); got != socialmedia.PlatformTwitter {
		t.Errorf("GetPlatform() = %v, want %v", got, socialmedia.PlatformTwitter)
	}
}

func TestTwitterScraper_FetchAccountInfo(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("Authorization") == "" {
			t.Error("Missing Authorization header")
		}

		response := map[string]interface{}{
			"data": map[string]interface{}{
				"id":                "123456",
				"name":              "Test User",
				"username":          "testuser",
				"description":       "Test bio",
				"profile_image_url": "https://example.com/image.jpg",
				"verified":          true,
				"created_at":        "2020-01-01T00:00:00.000Z",
			},
		}
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(response)
	}))
	defer server.Close()

	scraper := &TwitterScraper{
		bearerToken: "test-token",
		httpClient:  &http.Client{},
		baseURL:     server.URL,
	}

	ctx := context.Background()
	account, err := scraper.FetchAccountInfo(ctx, "testuser")
	if err != nil {
		t.Fatalf("FetchAccountInfo() error = %v", err)
	}

	if account.PlatformAccountID != "123456" {
		t.Errorf("PlatformAccountID = %v, want %v", account.PlatformAccountID, "123456")
	}
	if account.Username != "testuser" {
		t.Errorf("Username = %v, want %v", account.Username, "testuser")
	}
	if account.DisplayName != "Test User" {
		t.Errorf("DisplayName = %v, want %v", account.DisplayName, "Test User")
	}
	if !account.Verified {
		t.Error("Verified should be true")
	}
}

func TestTwitterScraper_FetchPosts(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		response := map[string]interface{}{
			"data": []map[string]interface{}{
				{
					"id":         "tweet123",
					"text":       "Test tweet",
					"created_at": "2024-01-01T00:00:00.000Z",
					"lang":       "en",
					"entities": map[string]interface{}{
						"hashtags": []map[string]interface{}{
							{"tag": "test"},
						},
						"mentions": []map[string]interface{}{
							{"username": "mentioned_user"},
						},
					},
					"public_metrics": map[string]interface{}{
						"like_count":    100.0,
						"retweet_count": 50.0,
					},
				},
			},
		}
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(response)
	}))
	defer server.Close()

	scraper := &TwitterScraper{
		bearerToken: "test-token",
		httpClient:  &http.Client{},
		baseURL:     server.URL,
	}

	ctx := context.Background()
	account := &socialmedia.Account{
		ID:                1,
		PlatformAccountID: "123456",
		Username:          "testuser",
	}

	posts, err := scraper.FetchPosts(ctx, account, testStartDate(), testEndDate())
	if err != nil {
		t.Fatalf("FetchPosts() error = %v", err)
	}

	if len(posts) != 1 {
		t.Errorf("FetchPosts() returned %d posts, want 1", len(posts))
	}

	post := posts[0]
	if post.PlatformPostID != "tweet123" {
		t.Errorf("PlatformPostID = %v, want %v", post.PlatformPostID, "tweet123")
	}
	if post.ContentText != "Test tweet" {
		t.Errorf("ContentText = %v, want %v", post.ContentText, "Test tweet")
	}
	if len(post.Hashtags) != 1 || post.Hashtags[0] != "test" {
		t.Errorf("Hashtags = %v, want [test]", post.Hashtags)
	}
	if len(post.Mentions) != 1 || post.Mentions[0] != "mentioned_user" {
		t.Errorf("Mentions = %v, want [mentioned_user]", post.Mentions)
	}
}

func TestTwitterScraper_FetchPostMetrics(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		response := map[string]interface{}{
			"data": map[string]interface{}{
				"id": "tweet123",
				"public_metrics": map[string]interface{}{
					"like_count":    150.0,
					"retweet_count": 75.0,
					"reply_count":   10.0,
					"quote_count":   5.0,
				},
				"non_public_metrics": map[string]interface{}{
					"impression_count": 10000.0,
				},
			},
		}
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(response)
	}))
	defer server.Close()

	scraper := &TwitterScraper{
		bearerToken: "test-token",
		httpClient:  &http.Client{},
		baseURL:     server.URL,
	}

	ctx := context.Background()
	post := &socialmedia.Post{
		ID:             1,
		PlatformPostID: "tweet123",
	}

	metrics, err := scraper.FetchPostMetrics(ctx, post, testStartDate(), testEndDate())
	if err != nil {
		t.Fatalf("FetchPostMetrics() error = %v", err)
	}

	if len(metrics) == 0 {
		t.Error("FetchPostMetrics() returned no metrics")
	}

	metric := metrics[0]
	if metric.Likes != 150 {
		t.Errorf("Likes = %v, want %v", metric.Likes, 150)
	}
	if metric.Retweets != 75 {
		t.Errorf("Retweets = %v, want %v", metric.Retweets, 75)
	}
	if metric.Impressions != 10000 {
		t.Errorf("Impressions = %v, want %v", metric.Impressions, 10000)
	}
}

func TestTwitterScraper_FetchAccountMetrics(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		response := map[string]interface{}{
			"data": map[string]interface{}{
				"id": "123456",
				"public_metrics": map[string]interface{}{
					"followers_count": 5000.0,
					"following_count": 500.0,
					"tweet_count":     1000.0,
				},
			},
		}
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(response)
	}))
	defer server.Close()

	scraper := &TwitterScraper{
		bearerToken: "test-token",
		httpClient:  &http.Client{},
		baseURL:     server.URL,
	}

	ctx := context.Background()
	account := &socialmedia.Account{
		ID:                1,
		PlatformAccountID: "123456",
	}

	metrics, err := scraper.FetchAccountMetrics(ctx, account, testStartDate(), testEndDate())
	if err != nil {
		t.Fatalf("FetchAccountMetrics() error = %v", err)
	}

	if len(metrics) == 0 {
		t.Error("FetchAccountMetrics() returned no metrics")
	}

	metric := metrics[0]
	if metric.FollowersTotal == nil || *metric.FollowersTotal != 5000 {
		t.Errorf("FollowersTotal = %v, want %v", metric.FollowersTotal, 5000)
	}
	if metric.TweetsPosted != 1000 {
		t.Errorf("TweetsPosted = %v, want %v", metric.TweetsPosted, 1000)
	}
}

// Helper functions
func testStartDate() time.Time {
	return time.Date(2024, 1, 1, 0, 0, 0, 0, time.UTC)
}

func testEndDate() time.Time {
	return time.Date(2024, 1, 31, 23, 59, 59, 0, time.UTC)
}
