package tiktok

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

// TikTokScraper scrapes metrics from TikTok for Business API
type TikTokScraper struct {
	accessToken string
	httpClient  *http.Client
	baseURL     string
}

// Config holds configuration for TikTok scraper
type Config struct {
	AppID       string // TikTok App ID
	AppSecret   string // TikTok App Secret
	AccessToken string // OAuth 2.0 access token
}

// NewScraper creates a new TikTok scraper
func NewScraper(cfg Config) (*TikTokScraper, error) {
	if cfg.AccessToken == "" {
		return nil, fmt.Errorf("access token is required for TikTok API")
	}

	return &TikTokScraper{
		accessToken: cfg.AccessToken,
		httpClient: &http.Client{
			Timeout: 30 * time.Second,
		},
		baseURL: "https://open.tiktokapis.com/v2",
	}, nil
}

// makeRequest is a helper function to make authenticated requests to TikTok API
func (s *TikTokScraper) makeRequest(ctx context.Context, endpoint string, params url.Values) (map[string]interface{}, error) {
	apiURL := fmt.Sprintf("%s/%s?%s", s.baseURL, endpoint, params.Encode())

	req, err := http.NewRequestWithContext(ctx, "GET", apiURL, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}

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
func (s *TikTokScraper) GetPlatform() socialmedia.Platform {
	return socialmedia.PlatformTikTok
}

// FetchAccountInfo fetches basic TikTok account information
func (s *TikTokScraper) FetchAccountInfo(ctx context.Context, username string) (*socialmedia.Account, error) {
	// TikTok API v2 user info endpoint
	params := url.Values{}
	params.Add("fields", "display_name,bio_description,avatar_url,is_verified,follower_count,following_count,likes_count,video_count")

	data, err := s.makeRequest(ctx, "user/info", params)
	if err != nil {
		return nil, err
	}

	account := &socialmedia.Account{
		Platform: socialmedia.PlatformTikTok,
		Username: username,
		RawData:  data,
	}

	// Parse user information
	if userData, ok := data["data"].(map[string]interface{}); ok {
		if userInfo, ok := userData["user"].(map[string]interface{}); ok {
			if openID, ok := userInfo["open_id"].(string); ok {
				account.PlatformAccountID = openID
			}
			if displayName, ok := userInfo["display_name"].(string); ok {
				account.DisplayName = displayName
			}
			if bio, ok := userInfo["bio_description"].(string); ok {
				account.Description = bio
			}
			if avatarURL, ok := userInfo["avatar_url"].(string); ok {
				account.ProfileImageURL = avatarURL
			}
			if verified, ok := userInfo["is_verified"].(bool); ok {
				account.Verified = verified
			}
		}
	}

	return account, nil
}

// FetchPosts fetches recent TikTok videos for an account
func (s *TikTokScraper) FetchPosts(ctx context.Context, account *socialmedia.Account, startDate, endDate time.Time) ([]*socialmedia.Post, error) {
	var posts []*socialmedia.Post

	// TikTok API v2 video list endpoint
	params := url.Values{}
	params.Add("fields", "id,title,video_description,create_time,cover_image_url,share_url,duration,height,width,hashtag_names")
	params.Add("max_count", "20") // Max 20 videos per request

	data, err := s.makeRequest(ctx, "video/list", params)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch videos: %w", err)
	}

	// Parse videos
	if videoData, ok := data["data"].(map[string]interface{}); ok {
		if videos, ok := videoData["videos"].([]interface{}); ok {
			for _, item := range videos {
				if video, ok := item.(map[string]interface{}); ok {
					post := &socialmedia.Post{
						AccountID:   account.ID,
						ContentType: "tiktok",
						RawData:     video,
					}

					if id, ok := video["id"].(string); ok {
						post.PlatformPostID = id
					}
					if title, ok := video["title"].(string); ok {
						post.Title = title
					}
					if description, ok := video["video_description"].(string); ok {
						post.ContentText = description
					}
					if shareURL, ok := video["share_url"].(string); ok {
						post.URL = shareURL
					}
					if duration, ok := video["duration"].(float64); ok {
						durationSec := int(duration)
						post.DurationSeconds = &durationSec
					}
					if createTime, ok := video["create_time"].(float64); ok {
						post.PublishedAt = time.Unix(int64(createTime), 0)
					}
					if hashtags, ok := video["hashtag_names"].([]interface{}); ok {
						for _, ht := range hashtags {
							if tag, ok := ht.(string); ok {
								post.Hashtags = append(post.Hashtags, tag)
							}
						}
					}

					// Only include posts within date range
					if post.PublishedAt.After(startDate) && post.PublishedAt.Before(endDate) {
						posts = append(posts, post)
					}
				}
			}
		}
	}

	return posts, nil
}

// FetchPostMetrics fetches metrics for a specific TikTok video
func (s *TikTokScraper) FetchPostMetrics(ctx context.Context, post *socialmedia.Post, startDate, endDate time.Time) ([]*socialmedia.PostMetrics, error) {
	// TikTok Business API provides video insights
	params := url.Values{}
	params.Add("video_ids", post.PlatformPostID)
	params.Add("fields", "views,likes,comments,shares,total_time_watched,average_time_watched,reach,full_video_watched_rate")

	data, err := s.makeRequest(ctx, "video/query", params)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch video metrics: %w", err)
	}

	var metrics []*socialmedia.PostMetrics

	if videoData, ok := data["data"].(map[string]interface{}); ok {
		if videos, ok := videoData["videos"].([]interface{}); ok && len(videos) > 0 {
			if video, ok := videos[0].(map[string]interface{}); ok {
				metric := &socialmedia.PostMetrics{
					PostID:     post.ID,
					MetricDate: time.Now(),
					RawData:    video,
				}

				if views, ok := video["views"].(float64); ok {
					metric.Views = int64(views)
				}
				if likes, ok := video["likes"].(float64); ok {
					metric.Likes = int64(likes)
				}
				if comments, ok := video["comments"].(float64); ok {
					metric.CommentsCount = int64(comments)
				}
				if shares, ok := video["shares"].(float64); ok {
					metric.Shares = int64(shares)
				}
				if reach, ok := video["reach"].(float64); ok {
					metric.Reach = int64(reach)
				}
				if totalWatched, ok := video["total_time_watched"].(float64); ok {
					metric.TotalTimeWatchedSeconds = int64(totalWatched)
				}
				if avgWatched, ok := video["average_time_watched"].(float64); ok {
					metric.AverageWatchTimeSeconds = int(avgWatched)
				}
				if completionRate, ok := video["full_video_watched_rate"].(float64); ok {
					rate := completionRate * 100 // Convert to percentage
					metric.CompletionRate = &rate
				}

				metrics = append(metrics, metric)
			}
		}
	}

	return metrics, nil
}

// FetchAccountMetrics fetches aggregate metrics for the TikTok account
func (s *TikTokScraper) FetchAccountMetrics(ctx context.Context, account *socialmedia.Account, startDate, endDate time.Time) ([]*socialmedia.AccountMetrics, error) {
	// Fetch user info which includes follower counts
	params := url.Values{}
	params.Add("fields", "follower_count,following_count,likes_count,video_count")

	data, err := s.makeRequest(ctx, "user/info", params)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch account metrics: %w", err)
	}

	metric := &socialmedia.AccountMetrics{
		AccountID:  account.ID,
		MetricDate: time.Now(),
		RawData:    data,
	}

	if userData, ok := data["data"].(map[string]interface{}); ok {
		if userInfo, ok := userData["user"].(map[string]interface{}); ok {
			if followers, ok := userInfo["follower_count"].(float64); ok {
				followersTotal := int64(followers)
				metric.FollowersTotal = &followersTotal
			}
			if following, ok := userInfo["following_count"].(float64); ok {
				followingTotal := int64(following)
				metric.FollowingTotal = &followingTotal
			}
			if videoCount, ok := userInfo["video_count"].(float64); ok {
				metric.VideosPosted = int(videoCount)
			}
			if likes, ok := userInfo["likes_count"].(float64); ok {
				metric.TotalLikes = int64(likes)
			}
		}
	}

	return []*socialmedia.AccountMetrics{metric}, nil
}

// FetchComments fetches comments for a TikTok video
func (s *TikTokScraper) FetchComments(ctx context.Context, post *socialmedia.Post) ([]*socialmedia.Comment, error) {
	// TikTok API v2 comments endpoint
	params := url.Values{}
	params.Add("video_id", post.PlatformPostID)
	params.Add("fields", "id,text,like_count,create_time,parent_comment_id")
	params.Add("max_count", "50")

	data, err := s.makeRequest(ctx, "video/comment/list", params)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch comments: %w", err)
	}

	var comments []*socialmedia.Comment

	if commentData, ok := data["data"].(map[string]interface{}); ok {
		if commentsArray, ok := commentData["comments"].([]interface{}); ok {
			for _, item := range commentsArray {
				if commentObj, ok := item.(map[string]interface{}); ok {
					comment := &socialmedia.Comment{
						PostID: post.ID,
					}

					if id, ok := commentObj["id"].(string); ok {
						comment.PlatformCommentID = id
					}
					if text, ok := commentObj["text"].(string); ok {
						comment.CommentText = text
					}
					if likes, ok := commentObj["like_count"].(float64); ok {
						comment.LikesCount = int(likes)
					}
					if createTime, ok := commentObj["create_time"].(float64); ok {
						comment.PublishedAt = time.Unix(int64(createTime), 0)
					}
					if _, ok := commentObj["parent_comment_id"].(string); ok {
						// Would need to map this to internal ID
						// For now, storing as nil
						comment.ParentCommentID = nil
					}

					comments = append(comments, comment)
				}
			}
		}
	}

	return comments, nil
}
