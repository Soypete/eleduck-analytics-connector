package twitch

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
			name: "valid config with access token",
			config: Config{
				ClientID:     "test-client-id",
				ClientSecret: "test-client-secret",
				AccessToken:  "test-access-token",
			},
			wantErr: false,
		},
		{
			name: "valid config without access token",
			config: Config{
				ClientID:     "test-client-id",
				ClientSecret: "test-client-secret",
			},
			wantErr: false, // Should get token automatically
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// For the case without access token, we need to mock the OAuth endpoint
			if tt.config.AccessToken == "" {
				server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
					if r.URL.Path == "/oauth2/token" {
						w.WriteHeader(http.StatusOK)
						json.NewEncoder(w).Encode(map[string]interface{}{
							"access_token": "mocked-token",
							"expires_in":   3600,
							"token_type":   "bearer",
						})
						return
					}
					w.WriteHeader(http.StatusNotFound)
				}))
				defer server.Close()

				// This test would need modification to use the test server
				// For now, we'll skip the OAuth flow test
				t.Skip("OAuth flow test requires server URL injection")
			}

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

func TestTwitchScraper_GetPlatform(t *testing.T) {
	scraper := &TwitchScraper{}
	if got := scraper.GetPlatform(); got != socialmedia.PlatformTwitch {
		t.Errorf("GetPlatform() = %v, want %v", got, socialmedia.PlatformTwitch)
	}
}

func TestTwitchScraper_FetchAccountInfo(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/users" {
			t.Errorf("Expected path /users, got %s", r.URL.Path)
		}

		// Check for required headers
		if r.Header.Get("Authorization") == "" {
			t.Error("Missing Authorization header")
		}
		if r.Header.Get("Client-ID") == "" {
			t.Error("Missing Client-ID header")
		}

		// Mock Twitch API response
		response := map[string]interface{}{
			"data": []map[string]interface{}{
				{
					"id":                "12345",
					"login":             "testuser",
					"display_name":      "Test User",
					"description":       "Test description",
					"profile_image_url": "https://example.com/image.jpg",
					"created_at":        "2020-01-01T00:00:00Z",
				},
			},
		}
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(response)
	}))
	defer server.Close()

	scraper := &TwitchScraper{
		clientID:    "test-client-id",
		accessToken: "test-token",
		httpClient:  &http.Client{},
		baseURL:     server.URL,
	}

	ctx := context.Background()
	account, err := scraper.FetchAccountInfo(ctx, "testuser")
	if err != nil {
		t.Fatalf("FetchAccountInfo() error = %v", err)
	}

	if account.PlatformAccountID != "12345" {
		t.Errorf("PlatformAccountID = %v, want %v", account.PlatformAccountID, "12345")
	}
	if account.Username != "testuser" {
		t.Errorf("Username = %v, want %v", account.Username, "testuser")
	}
	if account.DisplayName != "Test User" {
		t.Errorf("DisplayName = %v, want %v", account.DisplayName, "Test User")
	}
	if account.Description != "Test description" {
		t.Errorf("Description = %v, want %v", account.Description, "Test description")
	}
	if account.Platform != socialmedia.PlatformTwitch {
		t.Errorf("Platform = %v, want %v", account.Platform, socialmedia.PlatformTwitch)
	}
}

func TestTwitchScraper_FetchPosts(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/videos" {
			t.Errorf("Expected path /videos, got %s", r.URL.Path)
		}

		response := map[string]interface{}{
			"data": []map[string]interface{}{
				{
					"id":          "video123",
					"title":       "Test Stream",
					"description": "Test stream description",
					"url":         "https://twitch.tv/videos/video123",
					"created_at":  "2024-01-01T00:00:00Z",
					"type":        "archive",
					"duration":    "1h30m45s",
					"view_count":  1000.0,
				},
			},
		}
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(response)
	}))
	defer server.Close()

	scraper := &TwitchScraper{
		clientID:    "test-client-id",
		accessToken: "test-token",
		httpClient:  &http.Client{},
		baseURL:     server.URL,
	}

	ctx := context.Background()
	account := &socialmedia.Account{
		ID:                1,
		PlatformAccountID: "12345",
	}

	startDate := time.Date(2023, 1, 1, 0, 0, 0, 0, time.UTC)
	endDate := time.Date(2024, 12, 31, 0, 0, 0, 0, time.UTC)

	posts, err := scraper.FetchPosts(ctx, account, startDate, endDate)
	if err != nil {
		t.Fatalf("FetchPosts() error = %v", err)
	}

	if len(posts) != 1 {
		t.Errorf("FetchPosts() returned %d posts, want 1", len(posts))
	}

	post := posts[0]
	if post.PlatformPostID != "video123" {
		t.Errorf("PlatformPostID = %v, want %v", post.PlatformPostID, "video123")
	}
	if post.Title != "Test Stream" {
		t.Errorf("Title = %v, want %v", post.Title, "Test Stream")
	}
	if post.ContentType != "twitch_stream" {
		t.Errorf("ContentType = %v, want %v", post.ContentType, "twitch_stream")
	}
}

func TestTwitchScraper_FetchPostMetrics(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		response := map[string]interface{}{
			"data": []map[string]interface{}{
				{
					"id":         "video123",
					"view_count": 5000.0,
				},
			},
		}
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(response)
	}))
	defer server.Close()

	scraper := &TwitchScraper{
		clientID:    "test-client-id",
		accessToken: "test-token",
		httpClient:  &http.Client{},
		baseURL:     server.URL,
	}

	ctx := context.Background()
	post := &socialmedia.Post{
		ID:             1,
		PlatformPostID: "video123",
	}

	startDate := time.Now().AddDate(0, 0, -7)
	endDate := time.Now()

	metrics, err := scraper.FetchPostMetrics(ctx, post, startDate, endDate)
	if err != nil {
		t.Fatalf("FetchPostMetrics() error = %v", err)
	}

	if len(metrics) == 0 {
		t.Error("FetchPostMetrics() returned no metrics")
	}

	metric := metrics[0]
	if metric.Views != 5000 {
		t.Errorf("Views = %v, want %v", metric.Views, 5000)
	}
}

func TestTwitchScraper_FetchAccountMetrics(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		response := map[string]interface{}{
			"total": 10000.0,
		}
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(response)
	}))
	defer server.Close()

	scraper := &TwitchScraper{
		clientID:    "test-client-id",
		accessToken: "test-token",
		httpClient:  &http.Client{},
		baseURL:     server.URL,
	}

	ctx := context.Background()
	account := &socialmedia.Account{
		ID:                1,
		PlatformAccountID: "12345",
	}

	startDate := time.Now().AddDate(0, 0, -7)
	endDate := time.Now()

	metrics, err := scraper.FetchAccountMetrics(ctx, account, startDate, endDate)
	if err != nil {
		t.Fatalf("FetchAccountMetrics() error = %v", err)
	}

	if len(metrics) == 0 {
		t.Error("FetchAccountMetrics() returned no metrics")
	}

	metric := metrics[0]
	if metric.FollowersTotal == nil || *metric.FollowersTotal != 10000 {
		t.Errorf("FollowersTotal = %v, want %v", metric.FollowersTotal, 10000)
	}
}

func TestTwitchScraper_FetchComments(t *testing.T) {
	scraper := &TwitchScraper{}
	ctx := context.Background()
	post := &socialmedia.Post{ID: 1}

	_, err := scraper.FetchComments(ctx, post)
	if err == nil {
		t.Error("FetchComments() should return error (not implemented)")
	}
}
