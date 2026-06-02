package twitch

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"time"

	"github.com/soypete/eleduck-analytics-connector/internal/scrapers/socialmedia"
)

// TwitchScraper scrapes metrics from Twitch Helix API
type TwitchScraper struct {
	clientID     string
	clientSecret string
	accessToken  string
	httpClient   *http.Client
	baseURL      string
}

// Config holds configuration for Twitch scraper
type Config struct {
	ClientID     string // Twitch App Client ID
	ClientSecret string // Twitch App Client Secret
	AccessToken  string // OAuth 2.0 access token (if already obtained)
}

// NewScraper creates a new Twitch scraper
func NewScraper(cfg Config) (*TwitchScraper, error) {
	scraper := &TwitchScraper{
		clientID:     cfg.ClientID,
		clientSecret: cfg.ClientSecret,
		accessToken:  cfg.AccessToken,
		httpClient: &http.Client{
			Timeout: 30 * time.Second,
		},
		baseURL: "https://api.twitch.tv/helix",
	}

	// If no access token provided, get one using client credentials flow
	if scraper.accessToken == "" {
		token, err := scraper.getAccessToken(context.Background())
		if err != nil {
			return nil, fmt.Errorf("failed to obtain access token: %w", err)
		}
		scraper.accessToken = token
	}

	return scraper, nil
}

// getAccessToken obtains an OAuth 2.0 access token using client credentials flow
func (s *TwitchScraper) getAccessToken(ctx context.Context) (string, error) {
	tokenURL := "https://id.twitch.tv/oauth2/token"

	params := url.Values{}
	params.Add("client_id", s.clientID)
	params.Add("client_secret", s.clientSecret)
	params.Add("grant_type", "client_credentials")

	req, err := http.NewRequestWithContext(ctx, "POST", tokenURL, nil)
	if err != nil {
		return "", fmt.Errorf("failed to create token request: %w", err)
	}

	req.URL.RawQuery = params.Encode()

	resp, err := s.httpClient.Do(req)
	if err != nil {
		return "", fmt.Errorf("token request failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return "", fmt.Errorf("token API returned status %d: %s", resp.StatusCode, string(body))
	}

	var tokenResponse struct {
		AccessToken string `json:"access_token"`
		ExpiresIn   int    `json:"expires_in"`
		TokenType   string `json:"token_type"`
	}

	if err := json.NewDecoder(resp.Body).Decode(&tokenResponse); err != nil {
		return "", fmt.Errorf("failed to decode token response: %w", err)
	}

	return tokenResponse.AccessToken, nil
}

// makeRequest is a helper function to make authenticated requests to Twitch API
func (s *TwitchScraper) makeRequest(ctx context.Context, endpoint string, params url.Values) (map[string]interface{}, error) {
	apiURL := fmt.Sprintf("%s/%s?%s", s.baseURL, endpoint, params.Encode())

	req, err := http.NewRequestWithContext(ctx, "GET", apiURL, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}

	req.Header.Set("Client-ID", s.clientID)
	req.Header.Set("Authorization", "Bearer "+s.accessToken)

	resp, err := s.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("request failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("API returned status %d: %s", resp.StatusCode, string(body))
	}

	var result map[string]interface{}
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, fmt.Errorf("failed to decode response: %w", err)
	}

	return result, nil
}

// GetPlatform returns the platform identifier
func (s *TwitchScraper) GetPlatform() socialmedia.Platform {
	return socialmedia.PlatformTwitch
}

// FetchAccountInfo fetches basic Twitch channel information
func (s *TwitchScraper) FetchAccountInfo(ctx context.Context, username string) (*socialmedia.Account, error) {
	params := url.Values{}
	params.Add("login", username)

	data, err := s.makeRequest(ctx, "users", params)
	if err != nil {
		return nil, err
	}

	account := &socialmedia.Account{
		Platform: socialmedia.PlatformTwitch,
		Username: username,
		RawData:  data,
	}

	// Parse user information
	if items, ok := data["data"].([]interface{}); ok && len(items) > 0 {
		if user, ok := items[0].(map[string]interface{}); ok {
			if id, ok := user["id"].(string); ok {
				account.PlatformAccountID = id
			}
			if displayName, ok := user["display_name"].(string); ok {
				account.DisplayName = displayName
			}
			if description, ok := user["description"].(string); ok {
				account.Description = description
			}
			if profileImageURL, ok := user["profile_image_url"].(string); ok {
				account.ProfileImageURL = profileImageURL
			}
			if createdAt, ok := user["created_at"].(string); ok {
				if t, err := time.Parse(time.RFC3339, createdAt); err == nil {
					account.AccountCreatedAt = &t
				}
			}
		}
	}

	return account, nil
}

// FetchPosts fetches recent streams/videos for a Twitch channel
func (s *TwitchScraper) FetchPosts(ctx context.Context, account *socialmedia.Account, startDate, endDate time.Time) ([]*socialmedia.Post, error) {
	var posts []*socialmedia.Post

	// Fetch recent streams
	params := url.Values{}
	params.Add("user_id", account.PlatformAccountID)
	params.Add("first", "100") // Max results per page

	data, err := s.makeRequest(ctx, "videos", params)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch videos: %w", err)
	}

	// Parse videos/streams
	if items, ok := data["data"].([]interface{}); ok {
		for _, item := range items {
			if video, ok := item.(map[string]interface{}); ok {
				post := &socialmedia.Post{
					AccountID:   account.ID,
					ContentType: "twitch_stream",
					RawData:     video,
				}

				if id, ok := video["id"].(string); ok {
					post.PlatformPostID = id
				}
				if title, ok := video["title"].(string); ok {
					post.Title = title
				}
				if description, ok := video["description"].(string); ok {
					post.ContentText = description
				}
				if videoURL, ok := video["url"].(string); ok {
					post.URL = videoURL
				}
				if _, ok := video["duration"].(string); ok {
					// Parse duration (format: "1h2m3s")
					// TODO: Implement duration parsing
					post.DurationSeconds = nil
				}
				if createdAt, ok := video["created_at"].(string); ok {
					if t, err := time.Parse(time.RFC3339, createdAt); err == nil {
						post.PublishedAt = t
					}
				}
				if videoType, ok := video["type"].(string); ok {
					post.IsLive = videoType == "live"
				}

				// Only include posts within date range
				if post.PublishedAt.After(startDate) && post.PublishedAt.Before(endDate) {
					posts = append(posts, post)
				}
			}
		}
	}

	return posts, nil
}

// FetchPostMetrics fetches metrics for a specific stream/video
func (s *TwitchScraper) FetchPostMetrics(ctx context.Context, post *socialmedia.Post, startDate, endDate time.Time) ([]*socialmedia.PostMetrics, error) {
	// Note: Twitch Analytics API requires additional permissions and is limited
	// For basic metrics, we can get view count from the video data
	// For detailed analytics, would need Channel Analytics extension

	var metrics []*socialmedia.PostMetrics

	params := url.Values{}
	params.Add("id", post.PlatformPostID)

	data, err := s.makeRequest(ctx, "videos", params)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch video metrics: %w", err)
	}

	// Parse video data
	if items, ok := data["data"].([]interface{}); ok && len(items) > 0 {
		if video, ok := items[0].(map[string]interface{}); ok {
			metric := &socialmedia.PostMetrics{
				PostID:     post.ID,
				MetricDate: time.Now(), // Use current date as metric date
				RawData:    video,
			}

			if viewCount, ok := video["view_count"].(float64); ok {
				metric.Views = int64(viewCount)
			}

			metrics = append(metrics, metric)
		}
	}

	return metrics, nil
}

// FetchAccountMetrics fetches aggregate metrics for the Twitch channel
func (s *TwitchScraper) FetchAccountMetrics(ctx context.Context, account *socialmedia.Account, startDate, endDate time.Time) ([]*socialmedia.AccountMetrics, error) {
	// Fetch follower count
	params := url.Values{}
	params.Add("broadcaster_id", account.PlatformAccountID)

	data, err := s.makeRequest(ctx, "channels/followers", params)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch follower count: %w", err)
	}

	metric := &socialmedia.AccountMetrics{
		AccountID:  account.ID,
		MetricDate: time.Now(),
		RawData:    data,
	}

	if total, ok := data["total"].(float64); ok {
		followers := int64(total)
		metric.FollowersTotal = &followers
	}

	// Fetch subscriber count (requires channel:read:subscriptions scope)
	// This is a paid feature and requires special permissions
	// For now, we'll skip it unless user has the necessary scope

	return []*socialmedia.AccountMetrics{metric}, nil
}

// FetchComments fetches comments (Twitch doesn't have a direct comments API for VODs)
// This would require using the Chat API during live streams
func (s *TwitchScraper) FetchComments(ctx context.Context, post *socialmedia.Post) ([]*socialmedia.Comment, error) {
	// Twitch doesn't provide a REST API for fetching chat messages from VODs
	// Chat is only available via IRC/WebSocket during live streams
	// For historical chat, would need third-party services or IRC logs
	return nil, fmt.Errorf("Twitch comment fetching not implemented (requires IRC/WebSocket)")
}
