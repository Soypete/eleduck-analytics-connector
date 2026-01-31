package spotify

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/http/cookiejar"
	"strings"
	"time"

	"github.com/soypete/eleduck-analytics-connector/internal/scrapers"
)

// SpotifyScraper scrapes metrics from Spotify for Podcasters
type SpotifyScraper struct {
	accessToken string
	httpClient  *http.Client
	baseURL     string
}

// Config holds configuration for Spotify scraper
type Config struct {
	// Spotify uses cookie-based authentication for their podcaster dashboard
	// These would typically be extracted from browser session
	SpCookie     string // sp_dc cookie
	SpKeyCookie  string // sp_key cookie
}

// NewScraper creates a new Spotify scraper
func NewScraper(cfg Config) (*SpotifyScraper, error) {
	jar, err := cookiejar.New(nil)
	if err != nil {
		return nil, fmt.Errorf("failed to create cookie jar: %w", err)
	}

	scraper := &SpotifyScraper{
		httpClient: &http.Client{
			Jar:     jar,
			Timeout: 30 * time.Second,
		},
		baseURL: "https://podcasters.spotify.com",
	}

	// Set authentication cookies
	if cfg.SpCookie != "" {
		// In a real implementation, we would set the cookies here
		// This requires the actual cookie values from a logged-in session
	}

	return scraper, nil
}

// GetPlatform returns the platform identifier
func (s *SpotifyScraper) GetPlatform() scrapers.Platform {
	return scrapers.PlatformSpotify
}

// authenticate obtains access token for Spotify for Podcasters API
func (s *SpotifyScraper) authenticate(ctx context.Context) error {
	// Spotify for Podcasters uses an internal API that requires:
	// 1. Browser cookies (sp_dc, sp_key)
	// 2. Access token obtained via internal endpoints

	// This is a simplified implementation
	// Real implementation would extract and use actual session cookies

	authURL := fmt.Sprintf("%s/api/login", s.baseURL)

	req, err := http.NewRequestWithContext(ctx, "GET", authURL, nil)
	if err != nil {
		return fmt.Errorf("failed to create auth request: %w", err)
	}

	resp, err := s.httpClient.Do(req)
	if err != nil {
		return fmt.Errorf("auth request failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("authentication failed with status %d", resp.StatusCode)
	}

	return nil
}

// FetchPodcastInfo fetches basic podcast information
func (s *SpotifyScraper) FetchPodcastInfo(ctx context.Context, showName string) (*scrapers.Podcast, error) {
	if err := s.authenticate(ctx); err != nil {
		return nil, fmt.Errorf("authentication failed: %w", err)
	}

	// Spotify's internal API endpoint for show info
	// This is based on reverse-engineered endpoints from spotify-connector project
	return &scrapers.Podcast{
		ShowName:    showName,
		Platform:    scrapers.PlatformSpotify,
		Description: "Domesticating AI podcast",
		Language:    "en",
	}, nil
}

// FetchEpisodes fetches all episodes for a podcast
func (s *SpotifyScraper) FetchEpisodes(ctx context.Context, podcast *scrapers.Podcast) ([]*scrapers.Episode, error) {
	if err := s.authenticate(ctx); err != nil {
		return nil, fmt.Errorf("authentication failed: %w", err)
	}

	// Spotify internal API endpoint
	// Based on openpodcast/spotify-connector reverse engineering
	apiURL := fmt.Sprintf("%s/api/episodes?showId=%s", s.baseURL, podcast.PlatformID)

	req, err := http.NewRequestWithContext(ctx, "GET", apiURL, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}

	resp, err := s.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("request failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("API returned status %d", resp.StatusCode)
	}

	var episodes []*scrapers.Episode
	// Parse Spotify's response format
	// Placeholder implementation

	return episodes, nil
}

// FetchEpisodeMetrics fetches metrics for a specific episode
func (s *SpotifyScraper) FetchEpisodeMetrics(ctx context.Context, episode *scrapers.Episode, startDate, endDate time.Time) ([]*scrapers.EpisodeMetrics, error) {
	if err := s.authenticate(ctx); err != nil {
		return nil, fmt.Errorf("authentication failed: %w", err)
	}

	// Spotify for Podcasters internal API endpoints
	// Reference: https://github.com/openpodcast/spotify-connector
	apiURL := fmt.Sprintf("%s/api/analytics/episode/%s", s.baseURL, episode.PlatformEpisodeID)

	req, err := http.NewRequestWithContext(ctx, "POST", apiURL, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}

	// Spotify expects JSON payload with date range
	payload := map[string]interface{}{
		"startDate": startDate.Format("2006-01-02"),
		"endDate":   endDate.Format("2006-01-02"),
		"metrics":   []string{"starts", "streams", "listeners", "followers"},
	}

	payloadBytes, err := json.Marshal(payload)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal payload: %w", err)
	}

	req.Body = io.NopCloser(strings.NewReader(string(payloadBytes)))
	req.Header.Set("Content-Type", "application/json")

	resp, err := s.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("request failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("API returned status %d: %s", resp.StatusCode, string(body))
	}

	var metricsData map[string]interface{}
	if err := json.NewDecoder(resp.Body).Decode(&metricsData); err != nil {
		return nil, fmt.Errorf("failed to decode response: %w", err)
	}

	// Parse Spotify's metrics format
	// Spotify provides: starts, streams, listeners
	// A "play" in Spotify = 60+ seconds of listening
	metrics := []*scrapers.EpisodeMetrics{
		{
			EpisodeID:  episode.ID,
			MetricDate: time.Now(),
			RawData:    metricsData,
			// Map Spotify metrics:
			// - starts -> Plays
			// - streams -> Streams
			// - listeners -> Listeners
		},
	}

	return metrics, nil
}

// FetchShowMetrics fetches aggregate metrics for the show
func (s *SpotifyScraper) FetchShowMetrics(ctx context.Context, podcast *scrapers.Podcast, startDate, endDate time.Time) ([]*scrapers.ShowMetrics, error) {
	if err := s.authenticate(ctx); err != nil {
		return nil, fmt.Errorf("authentication failed: %w", err)
	}

	apiURL := fmt.Sprintf("%s/api/analytics/show/%s", s.baseURL, podcast.PlatformID)

	req, err := http.NewRequestWithContext(ctx, "POST", apiURL, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}

	payload := map[string]interface{}{
		"startDate": startDate.Format("2006-01-02"),
		"endDate":   endDate.Format("2006-01-02"),
	}

	payloadBytes, err := json.Marshal(payload)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal payload: %w", err)
	}

	req.Body = io.NopCloser(strings.NewReader(string(payloadBytes)))
	req.Header.Set("Content-Type", "application/json")

	resp, err := s.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("request failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("API returned status %d", resp.StatusCode)
	}

	var metricsData map[string]interface{}
	if err := json.NewDecoder(resp.Body).Decode(&metricsData); err != nil {
		return nil, fmt.Errorf("failed to decode response: %w", err)
	}

	metrics := []*scrapers.ShowMetrics{
		{
			PodcastID:  podcast.ID,
			MetricDate: time.Now(),
			RawData:    metricsData,
		},
	}

	return metrics, nil
}

// FetchComments - Spotify for Podcasters doesn't support comments
func (s *SpotifyScraper) FetchComments(ctx context.Context, episode *scrapers.Episode) ([]*scrapers.Comment, error) {
	// Spotify doesn't have podcast comments
	return []*scrapers.Comment{}, nil
}
