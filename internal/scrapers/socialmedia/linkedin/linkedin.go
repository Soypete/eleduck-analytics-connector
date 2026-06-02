package linkedin

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

// LinkedInScraper scrapes metrics from LinkedIn Marketing API
type LinkedInScraper struct {
	accessToken string
	httpClient  *http.Client
	baseURL     string
}

// Config holds configuration for LinkedIn scraper
type Config struct {
	ClientID     string // LinkedIn App Client ID
	ClientSecret string // LinkedIn App Client Secret
	AccessToken  string // OAuth 2.0 access token
}

// NewScraper creates a new LinkedIn scraper
func NewScraper(cfg Config) (*LinkedInScraper, error) {
	if cfg.AccessToken == "" {
		return nil, fmt.Errorf("access token is required for LinkedIn API")
	}

	return &LinkedInScraper{
		accessToken: cfg.AccessToken,
		httpClient: &http.Client{
			Timeout: 30 * time.Second,
		},
		baseURL: "https://api.linkedin.com/v2",
	}, nil
}

// makeRequest is a helper function to make authenticated requests to LinkedIn API
func (s *LinkedInScraper) makeRequest(ctx context.Context, endpoint string, params url.Values) (map[string]interface{}, error) {
	apiURL := fmt.Sprintf("%s/%s", s.baseURL, endpoint)
	if len(params) > 0 {
		apiURL = fmt.Sprintf("%s?%s", apiURL, params.Encode())
	}

	req, err := http.NewRequestWithContext(ctx, "GET", apiURL, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}

	req.Header.Set("Authorization", "Bearer "+s.accessToken)
	req.Header.Set("X-Restli-Protocol-Version", "2.0.0")

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
func (s *LinkedInScraper) GetPlatform() socialmedia.Platform {
	return socialmedia.PlatformLinkedIn
}

// FetchAccountInfo fetches basic LinkedIn profile/organization information
func (s *LinkedInScraper) FetchAccountInfo(ctx context.Context, username string) (*socialmedia.Account, error) {
	// LinkedIn API uses person/organization URNs, not usernames
	// For personal profiles, we need to use "me" endpoint if we have the user's token
	// For organizations, we need the organization ID

	// Using "me" endpoint for the authenticated user
	data, err := s.makeRequest(ctx, "me", url.Values{})
	if err != nil {
		return nil, err
	}

	account := &socialmedia.Account{
		Platform: socialmedia.PlatformLinkedIn,
		Username: username,
		RawData:  data,
	}

	// Parse person information
	if id, ok := data["id"].(string); ok {
		account.PlatformAccountID = id
	}
	if localizedFirstName, ok := data["localizedFirstName"].(string); ok {
		displayName := localizedFirstName
		if localizedLastName, ok := data["localizedLastName"].(string); ok {
			displayName = fmt.Sprintf("%s %s", localizedFirstName, localizedLastName)
		}
		account.DisplayName = displayName
	}
	if profilePicture, ok := data["profilePicture"].(map[string]interface{}); ok {
		// Extract profile image URL from complex nested structure
		// This is simplified - actual structure is more complex
		account.ProfileImageURL = fmt.Sprintf("%v", profilePicture)
	}

	return account, nil
}

// FetchPosts fetches recent LinkedIn posts/shares for an account
func (s *LinkedInScraper) FetchPosts(ctx context.Context, account *socialmedia.Account, startDate, endDate time.Time) ([]*socialmedia.Post, error) {
	// Note: LinkedIn API for personal posts is very limited
	// Organization posts are more accessible via ugcPosts endpoint

	var posts []*socialmedia.Post

	// For organization posts:
	params := url.Values{}
	params.Add("q", "author")
	params.Add("author", fmt.Sprintf("urn:li:organization:%s", account.PlatformAccountID))
	params.Add("count", "50")

	data, err := s.makeRequest(ctx, "ugcPosts", params)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch posts: %w", err)
	}

	// Parse posts
	if elements, ok := data["elements"].([]interface{}); ok {
		for _, item := range elements {
			if postData, ok := item.(map[string]interface{}); ok {
				post := &socialmedia.Post{
					AccountID:   account.ID,
					ContentType: "linkedin_post",
					RawData:     postData,
				}

				if id, ok := postData["id"].(string); ok {
					post.PlatformPostID = id
				}
				if specificContent, ok := postData["specificContent"].(map[string]interface{}); ok {
					if shareContent, ok := specificContent["com.linkedin.ugc.ShareContent"].(map[string]interface{}); ok {
						if shareCommentary, ok := shareContent["shareCommentary"].(map[string]interface{}); ok {
							if text, ok := shareCommentary["text"].(string); ok {
								post.ContentText = text
							}
						}
					}
				}
				if created, ok := postData["created"].(map[string]interface{}); ok {
					if timestamp, ok := created["time"].(float64); ok {
						post.PublishedAt = time.Unix(int64(timestamp)/1000, 0)
					}
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

// FetchPostMetrics fetches metrics for a specific LinkedIn post
func (s *LinkedInScraper) FetchPostMetrics(ctx context.Context, post *socialmedia.Post, startDate, endDate time.Time) ([]*socialmedia.PostMetrics, error) {
	// LinkedIn analytics require Marketing Developer Platform access
	// and work better for organization pages

	params := url.Values{}
	params.Add("q", "ugcPost")
	params.Add("ugcPost", post.PlatformPostID)

	data, err := s.makeRequest(ctx, "organizationSocialActions", params)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch post metrics: %w", err)
	}

	var metrics []*socialmedia.PostMetrics

	if elements, ok := data["elements"].([]interface{}); ok && len(elements) > 0 {
		if element, ok := elements[0].(map[string]interface{}); ok {
			metric := &socialmedia.PostMetrics{
				PostID:     post.ID,
				MetricDate: time.Now(),
				RawData:    element,
			}

			if totalShareStatistics, ok := element["totalShareStatistics"].(map[string]interface{}); ok {
				if clicks, ok := totalShareStatistics["clickCount"].(float64); ok {
					metric.Clicks = int64(clicks)
				}
				if likes, ok := totalShareStatistics["likeCount"].(float64); ok {
					metric.Likes = int64(likes)
				}
				if comments, ok := totalShareStatistics["commentCount"].(float64); ok {
					metric.CommentsCount = int64(comments)
				}
				if shares, ok := totalShareStatistics["shareCount"].(float64); ok {
					metric.Shares = int64(shares)
				}
				if impressions, ok := totalShareStatistics["impressionCount"].(float64); ok {
					metric.Impressions = int64(impressions)
				}
				if engagement, ok := totalShareStatistics["engagement"].(float64); ok {
					metric.Engagements = int64(engagement)
				}
			}

			metrics = append(metrics, metric)
		}
	}

	return metrics, nil
}

// FetchAccountMetrics fetches aggregate metrics for the LinkedIn account/organization
func (s *LinkedInScraper) FetchAccountMetrics(ctx context.Context, account *socialmedia.Account, startDate, endDate time.Time) ([]*socialmedia.AccountMetrics, error) {
	// For organizations, we can fetch follower statistics
	params := url.Values{}
	params.Add("q", "organization")
	params.Add("organization", fmt.Sprintf("urn:li:organization:%s", account.PlatformAccountID))

	data, err := s.makeRequest(ctx, "networkSizes", params)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch account metrics: %w", err)
	}

	metric := &socialmedia.AccountMetrics{
		AccountID:  account.ID,
		MetricDate: time.Now(),
		RawData:    data,
	}

	if elements, ok := data["elements"].([]interface{}); ok && len(elements) > 0 {
		if element, ok := elements[0].(map[string]interface{}); ok {
			if firstDegreeSize, ok := element["firstDegreeSize"].(float64); ok {
				followers := int64(firstDegreeSize)
				metric.FollowersTotal = &followers
			}
		}
	}

	// Fetch page statistics (for organizations with Marketing Developer Platform access)
	pageParams := url.Values{}
	pageParams.Add("q", "organization")
	pageParams.Add("organization", fmt.Sprintf("urn:li:organization:%s", account.PlatformAccountID))
	pageParams.Add("timeIntervals.timeGranularityType", "DAY")
	pageParams.Add("timeIntervals.timeRange.start", fmt.Sprintf("%d", startDate.UnixMilli()))
	pageParams.Add("timeIntervals.timeRange.end", fmt.Sprintf("%d", endDate.UnixMilli()))

	pageData, err := s.makeRequest(ctx, "organizationPageStatistics", pageParams)
	if err == nil {
		if elements, ok := pageData["elements"].([]interface{}); ok && len(elements) > 0 {
			if element, ok := elements[0].(map[string]interface{}); ok {
				if totalPageStats, ok := element["totalPageStatistics"].(map[string]interface{}); ok {
					if views, ok := totalPageStats["views"].(map[string]interface{}); ok {
						if pageViews, ok := views["allPageViews"].(map[string]interface{}); ok {
							if pageViewsTotal, ok := pageViews["pageViews"].(float64); ok {
								metric.ProfileViews = int64(pageViewsTotal)
							}
						}
					}
				}
			}
		}
	}

	return []*socialmedia.AccountMetrics{metric}, nil
}

// FetchComments fetches comments for a LinkedIn post
func (s *LinkedInScraper) FetchComments(ctx context.Context, post *socialmedia.Post) ([]*socialmedia.Comment, error) {
	// LinkedIn API v2 comments endpoint
	params := url.Values{}
	params.Add("q", "ugcPost")
	params.Add("ugcPost", post.PlatformPostID)
	params.Add("count", "100")

	data, err := s.makeRequest(ctx, "socialActions", params)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch comments: %w", err)
	}

	var comments []*socialmedia.Comment

	if elements, ok := data["elements"].([]interface{}); ok {
		for _, item := range elements {
			if commentData, ok := item.(map[string]interface{}); ok {
				comment := &socialmedia.Comment{
					PostID: post.ID,
				}

				if id, ok := commentData["id"].(string); ok {
					comment.PlatformCommentID = id
				}
				if message, ok := commentData["message"].(map[string]interface{}); ok {
					if text, ok := message["text"].(string); ok {
						comment.CommentText = text
					}
				}
				if actor, ok := commentData["actor"].(string); ok {
					comment.AuthorID = actor
				}
				if created, ok := commentData["created"].(map[string]interface{}); ok {
					if timestamp, ok := created["time"].(float64); ok {
						comment.PublishedAt = time.Unix(int64(timestamp)/1000, 0)
					}
				}

				comments = append(comments, comment)
			}
		}
	}

	return comments, nil
}
