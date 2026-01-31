package youtube

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"time"

	"github.com/soypete/eleduck-analytics-connector/internal/scrapers"
)

// YouTubeScraper scrapes metrics from YouTube Analytics API
type YouTubeScraper struct {
	apiKey     string
	httpClient *http.Client
	baseURL    string
}

// Config holds configuration for YouTube scraper
type Config struct {
	// YouTube Analytics API requires OAuth 2.0 or API Key
	APIKey      string
	AccessToken string // OAuth 2.0 access token
}

// NewScraper creates a new YouTube scraper
func NewScraper(cfg Config) (*YouTubeScraper, error) {
	return &YouTubeScraper{
		apiKey: cfg.APIKey,
		httpClient: &http.Client{
			Timeout: 30 * time.Second,
		},
		baseURL: "https://youtubeanalytics.googleapis.com/v2",
	}, nil
}

// GetPlatform returns the platform identifier
func (s *YouTubeScraper) GetPlatform() scrapers.Platform {
	return scrapers.PlatformYouTube
}

// FetchPodcastInfo fetches basic channel/show information
func (s *YouTubeScraper) FetchPodcastInfo(ctx context.Context, showName string) (*scrapers.Podcast, error) {
	// For YouTube, we need to get channel information
	// Use YouTube Data API v3 to get channel details
	dataAPIURL := "https://www.googleapis.com/youtube/v3/channels"

	// Build request
	params := url.Values{}
	params.Add("part", "snippet,statistics")
	params.Add("forUsername", showName) // or use channel ID
	params.Add("key", s.apiKey)

	apiURL := fmt.Sprintf("%s?%s", dataAPIURL, params.Encode())

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
		body, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("API returned status %d: %s", resp.StatusCode, string(body))
	}

	var channelData map[string]interface{}
	if err := json.NewDecoder(resp.Body).Decode(&channelData); err != nil {
		return nil, fmt.Errorf("failed to decode response: %w", err)
	}

	// Parse channel information
	podcast := &scrapers.Podcast{
		ShowName:   showName,
		Platform:   scrapers.PlatformYouTube,
		RawData:    channelData,
	}

	// Extract from response
	if items, ok := channelData["items"].([]interface{}); ok && len(items) > 0 {
		if item, ok := items[0].(map[string]interface{}); ok {
			if id, ok := item["id"].(string); ok {
				podcast.PlatformID = id
			}
			if snippet, ok := item["snippet"].(map[string]interface{}); ok {
				if desc, ok := snippet["description"].(string); ok {
					podcast.Description = desc
				}
			}
		}
	}

	return podcast, nil
}

// FetchEpisodes fetches all videos/episodes for a channel
func (s *YouTubeScraper) FetchEpisodes(ctx context.Context, podcast *scrapers.Podcast) ([]*scrapers.Episode, error) {
	// Use YouTube Data API v3 to get channel videos
	dataAPIURL := "https://www.googleapis.com/youtube/v3/search"

	params := url.Values{}
	params.Add("part", "snippet")
	params.Add("channelId", podcast.PlatformID)
	params.Add("type", "video")
	params.Add("order", "date")
	params.Add("maxResults", "50")
	params.Add("key", s.apiKey)

	apiURL := fmt.Sprintf("%s?%s", dataAPIURL, params.Encode())

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
		body, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("API returned status %d: %s", resp.StatusCode, string(body))
	}

	var videosData map[string]interface{}
	if err := json.NewDecoder(resp.Body).Decode(&videosData); err != nil {
		return nil, fmt.Errorf("failed to decode response: %w", err)
	}

	var episodes []*scrapers.Episode

	// Parse videos from response
	if items, ok := videosData["items"].([]interface{}); ok {
		for _, item := range items {
			if videoItem, ok := item.(map[string]interface{}); ok {
				episode := &scrapers.Episode{
					PodcastID: podcast.ID,
				}

				if id, ok := videoItem["id"].(map[string]interface{}); ok {
					if videoID, ok := id["videoId"].(string); ok {
						episode.PlatformEpisodeID = videoID
					}
				}

				if snippet, ok := videoItem["snippet"].(map[string]interface{}); ok {
					if title, ok := snippet["title"].(string); ok {
						episode.EpisodeTitle = title
					}
					if desc, ok := snippet["description"].(string); ok {
						episode.Description = desc
					}
					if publishedAt, ok := snippet["publishedAt"].(string); ok {
						if t, err := time.Parse(time.RFC3339, publishedAt); err == nil {
							episode.PublishDate = t
						}
					}
				}

				episodes = append(episodes, episode)
			}
		}
	}

	return episodes, nil
}

// FetchEpisodeMetrics fetches metrics for a specific video/episode
func (s *YouTubeScraper) FetchEpisodeMetrics(ctx context.Context, episode *scrapers.Episode, startDate, endDate time.Time) ([]*scrapers.EpisodeMetrics, error) {
	// YouTube Analytics API v2
	// https://youtubeanalytics.googleapis.com/v2/reports

	params := url.Values{}
	params.Add("ids", "channel==MINE") // or specific channel ID
	params.Add("startDate", startDate.Format("2006-01-02"))
	params.Add("endDate", endDate.Format("2006-01-02"))
	params.Add("metrics", "views,likes,dislikes,comments,shares,estimatedMinutesWatched,averageViewDuration,subscribersGained,subscribersLost")
	params.Add("dimensions", "day")
	params.Add("filters", fmt.Sprintf("video==%s", episode.PlatformEpisodeID))

	apiURL := fmt.Sprintf("%s/reports?%s", s.baseURL, params.Encode())

	req, err := http.NewRequestWithContext(ctx, "GET", apiURL, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}

	// Add OAuth token
	req.Header.Set("Authorization", fmt.Sprintf("Bearer %s", s.apiKey))

	resp, err := s.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("request failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("API returned status %d: %s", resp.StatusCode, string(body))
	}

	var analyticsData map[string]interface{}
	if err := json.NewDecoder(resp.Body).Decode(&analyticsData); err != nil {
		return nil, fmt.Errorf("failed to decode response: %w", err)
	}

	var metrics []*scrapers.EpisodeMetrics

	// Parse YouTube Analytics response
	// Response format includes columnHeaders and rows
	if rows, ok := analyticsData["rows"].([]interface{}); ok {
		for _, row := range rows {
			if rowData, ok := row.([]interface{}); ok && len(rowData) >= 9 {
				metric := &scrapers.EpisodeMetrics{
					EpisodeID: episode.ID,
					RawData:   analyticsData,
				}

				// Parse date (first column)
				if dateStr, ok := rowData[0].(string); ok {
					if t, err := time.Parse("2006-01-02", dateStr); err == nil {
						metric.MetricDate = t
					}
				}

				// Map YouTube metrics to our schema
				if views, ok := rowData[1].(float64); ok {
					metric.Views = int64(views)
				}
				if likes, ok := rowData[2].(float64); ok {
					metric.Likes = int64(likes)
				}
				if dislikes, ok := rowData[3].(float64); ok {
					metric.Dislikes = int64(dislikes)
				}
				if comments, ok := rowData[4].(float64); ok {
					metric.CommentsCount = int64(comments)
				}
				if shares, ok := rowData[5].(float64); ok {
					metric.Shares = int64(shares)
				}
				if watchTime, ok := rowData[6].(float64); ok {
					metric.WatchTimeMinutes = int64(watchTime)
				}
				if avgDuration, ok := rowData[7].(float64); ok {
					metric.AverageViewDuration = int(avgDuration)
				}
				if subGained, ok := rowData[8].(float64); ok {
					metric.SubscribersGained = int(subGained)
				}
				if subLost, ok := rowData[9].(float64); ok {
					metric.SubscribersLost = int(subLost)
				}

				metrics = append(metrics, metric)
			}
		}
	}

	return metrics, nil
}

// FetchShowMetrics fetches aggregate metrics for the channel
func (s *YouTubeScraper) FetchShowMetrics(ctx context.Context, podcast *scrapers.Podcast, startDate, endDate time.Time) ([]*scrapers.ShowMetrics, error) {
	// YouTube Analytics API for channel-level metrics

	params := url.Values{}
	params.Add("ids", fmt.Sprintf("channel==%s", podcast.PlatformID))
	params.Add("startDate", startDate.Format("2006-01-02"))
	params.Add("endDate", endDate.Format("2006-01-02"))
	params.Add("metrics", "views,likes,comments,shares,subscribersGained,subscribersLost,estimatedMinutesWatched")
	params.Add("dimensions", "day")

	apiURL := fmt.Sprintf("%s/reports?%s", s.baseURL, params.Encode())

	req, err := http.NewRequestWithContext(ctx, "GET", apiURL, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}

	req.Header.Set("Authorization", fmt.Sprintf("Bearer %s", s.apiKey))

	resp, err := s.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("request failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("API returned status %d", resp.StatusCode)
	}

	var analyticsData map[string]interface{}
	if err := json.NewDecoder(resp.Body).Decode(&analyticsData); err != nil {
		return nil, fmt.Errorf("failed to decode response: %w", err)
	}

	var metrics []*scrapers.ShowMetrics

	// Parse channel metrics
	if rows, ok := analyticsData["rows"].([]interface{}); ok {
		for _, row := range rows {
			if rowData, ok := row.([]interface{}); ok {
				metric := &scrapers.ShowMetrics{
					PodcastID: podcast.ID,
					RawData:   analyticsData,
				}

				// Parse and map metrics
				if dateStr, ok := rowData[0].(string); ok {
					if t, err := time.Parse("2006-01-02", dateStr); err == nil {
						metric.MetricDate = t
					}
				}

				metrics = append(metrics, metric)
			}
		}
	}

	return metrics, nil
}

// FetchComments fetches comments for a video
func (s *YouTubeScraper) FetchComments(ctx context.Context, episode *scrapers.Episode) ([]*scrapers.Comment, error) {
	// Use YouTube Data API v3 to get comments
	dataAPIURL := "https://www.googleapis.com/youtube/v3/commentThreads"

	params := url.Values{}
	params.Add("part", "snippet")
	params.Add("videoId", episode.PlatformEpisodeID)
	params.Add("maxResults", "100")
	params.Add("order", "relevance")
	params.Add("key", s.apiKey)

	apiURL := fmt.Sprintf("%s?%s", dataAPIURL, params.Encode())

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
		body, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("API returned status %d: %s", resp.StatusCode, string(body))
	}

	var commentsData map[string]interface{}
	if err := json.NewDecoder(resp.Body).Decode(&commentsData); err != nil {
		return nil, fmt.Errorf("failed to decode response: %w", err)
	}

	var comments []*scrapers.Comment

	// Parse comments from response
	if items, ok := commentsData["items"].([]interface{}); ok {
		for _, item := range items {
			if commentItem, ok := item.(map[string]interface{}); ok {
				comment := &scrapers.Comment{
					EpisodeID: episode.ID,
				}

				if id, ok := commentItem["id"].(string); ok {
					comment.PlatformCommentID = id
				}

				if snippet, ok := commentItem["snippet"].(map[string]interface{}); ok {
					if topLevelComment, ok := snippet["topLevelComment"].(map[string]interface{}); ok {
						if commentSnippet, ok := topLevelComment["snippet"].(map[string]interface{}); ok {
							if text, ok := commentSnippet["textDisplay"].(string); ok {
								comment.CommentText = text
							}
							if authorName, ok := commentSnippet["authorDisplayName"].(string); ok {
								comment.AuthorName = authorName
							}
							if authorID, ok := commentSnippet["authorChannelId"].(map[string]interface{}); ok {
								if value, ok := authorID["value"].(string); ok {
									comment.AuthorID = value
								}
							}
							if likes, ok := commentSnippet["likeCount"].(float64); ok {
								comment.LikesCount = int(likes)
							}
							if publishedAt, ok := commentSnippet["publishedAt"].(string); ok {
								if t, err := time.Parse(time.RFC3339, publishedAt); err == nil {
									comment.PublishedAt = t
								}
							}
						}
					}
					if replyCount, ok := snippet["totalReplyCount"].(float64); ok {
						comment.ReplyCount = int(replyCount)
					}
				}

				comments = append(comments, comment)
			}
		}
	}

	return comments, nil
}
