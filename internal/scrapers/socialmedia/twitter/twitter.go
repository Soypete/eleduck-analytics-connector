package twitter

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

// TwitterScraper scrapes metrics from Twitter/X API v2
type TwitterScraper struct {
	bearerToken string
	httpClient  *http.Client
	baseURL     string
}

// Config holds configuration for Twitter scraper
type Config struct {
	BearerToken string // Twitter API v2 Bearer Token (requires Basic tier $100/mo for analytics)
	// Alternative: OAuth 2.0 credentials
	APIKey       string
	APISecret    string
	AccessToken  string
	AccessSecret string
}

// NewScraper creates a new Twitter scraper
func NewScraper(cfg Config) (*TwitterScraper, error) {
	if cfg.BearerToken == "" && cfg.AccessToken == "" {
		return nil, fmt.Errorf("either bearer token or OAuth credentials required")
	}

	return &TwitterScraper{
		bearerToken: cfg.BearerToken,
		httpClient: &http.Client{
			Timeout: 30 * time.Second,
		},
		baseURL: "https://api.twitter.com/2",
	}, nil
}

// makeRequest is a helper function to make authenticated requests to Twitter API
func (s *TwitterScraper) makeRequest(ctx context.Context, endpoint string, params url.Values) (map[string]interface{}, error) {
	apiURL := fmt.Sprintf("%s/%s?%s", s.baseURL, endpoint, params.Encode())

	req, err := http.NewRequestWithContext(ctx, "GET", apiURL, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}

	req.Header.Set("Authorization", "Bearer "+s.bearerToken)

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
func (s *TwitterScraper) GetPlatform() socialmedia.Platform {
	return socialmedia.PlatformTwitter
}

// FetchAccountInfo fetches basic Twitter account information
func (s *TwitterScraper) FetchAccountInfo(ctx context.Context, username string) (*socialmedia.Account, error) {
	params := url.Values{}
	params.Add("user.fields", "id,name,username,description,profile_image_url,verified,created_at,public_metrics")

	data, err := s.makeRequest(ctx, fmt.Sprintf("users/by/username/%s", username), params)
	if err != nil {
		return nil, err
	}

	account := &socialmedia.Account{
		Platform: socialmedia.PlatformTwitter,
		Username: username,
		RawData:  data,
	}

	// Parse user information
	if userData, ok := data["data"].(map[string]interface{}); ok {
		if id, ok := userData["id"].(string); ok {
			account.PlatformAccountID = id
		}
		if name, ok := userData["name"].(string); ok {
			account.DisplayName = name
		}
		if description, ok := userData["description"].(string); ok {
			account.Description = description
		}
		if profileImageURL, ok := userData["profile_image_url"].(string); ok {
			account.ProfileImageURL = profileImageURL
		}
		if verified, ok := userData["verified"].(bool); ok {
			account.Verified = verified
		}
		if createdAt, ok := userData["created_at"].(string); ok {
			if t, err := time.Parse(time.RFC3339, createdAt); err == nil {
				account.AccountCreatedAt = &t
			}
		}
	}

	return account, nil
}

// FetchPosts fetches recent tweets for a Twitter account
func (s *TwitterScraper) FetchPosts(ctx context.Context, account *socialmedia.Account, startDate, endDate time.Time) ([]*socialmedia.Post, error) {
	var posts []*socialmedia.Post

	params := url.Values{}
	params.Add("max_results", "100") // Max 100 tweets per request
	params.Add("tweet.fields", "id,text,created_at,public_metrics,entities,lang,referenced_tweets")
	params.Add("start_time", startDate.Format(time.RFC3339))
	params.Add("end_time", endDate.Format(time.RFC3339))

	data, err := s.makeRequest(ctx, fmt.Sprintf("users/%s/tweets", account.PlatformAccountID), params)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch tweets: %w", err)
	}

	// Parse tweets
	if items, ok := data["data"].([]interface{}); ok {
		for _, item := range items {
			if tweet, ok := item.(map[string]interface{}); ok {
				post := &socialmedia.Post{
					AccountID:   account.ID,
					ContentType: "tweet",
					RawData:     tweet,
				}

				if id, ok := tweet["id"].(string); ok {
					post.PlatformPostID = id
					post.URL = fmt.Sprintf("https://twitter.com/%s/status/%s", account.Username, id)
				}
				if text, ok := tweet["text"].(string); ok {
					post.ContentText = text
				}
				if lang, ok := tweet["lang"].(string); ok {
					post.Language = lang
				}
				if createdAt, ok := tweet["created_at"].(string); ok {
					if t, err := time.Parse(time.RFC3339, createdAt); err == nil {
						post.PublishedAt = t
					}
				}

				// Extract hashtags and mentions from entities
				if entities, ok := tweet["entities"].(map[string]interface{}); ok {
					if hashtags, ok := entities["hashtags"].([]interface{}); ok {
						for _, ht := range hashtags {
							if htMap, ok := ht.(map[string]interface{}); ok {
								if tag, ok := htMap["tag"].(string); ok {
									post.Hashtags = append(post.Hashtags, tag)
								}
							}
						}
					}
					if mentions, ok := entities["mentions"].([]interface{}); ok {
						for _, mention := range mentions {
							if mentionMap, ok := mention.(map[string]interface{}); ok {
								if username, ok := mentionMap["username"].(string); ok {
									post.Mentions = append(post.Mentions, username)
								}
							}
						}
					}
				}

				// Check if it's a retweet
				if refTweets, ok := tweet["referenced_tweets"].([]interface{}); ok {
					for _, ref := range refTweets {
						if refMap, ok := ref.(map[string]interface{}); ok {
							if refType, ok := refMap["type"].(string); ok {
								if refType == "retweeted" {
									post.ContentType = "retweet"
									break
								}
							}
						}
					}
				}

				posts = append(posts, post)
			}
		}
	}

	return posts, nil
}

// FetchPostMetrics fetches metrics for a specific tweet
func (s *TwitterScraper) FetchPostMetrics(ctx context.Context, post *socialmedia.Post, startDate, endDate time.Time) ([]*socialmedia.PostMetrics, error) {
	// Note: Detailed tweet analytics require Twitter API Basic tier ($100/mo)
	// Free tier only provides public metrics (likes, retweets, replies, quotes)

	params := url.Values{}
	params.Add("tweet.fields", "public_metrics,non_public_metrics,organic_metrics")

	data, err := s.makeRequest(ctx, fmt.Sprintf("tweets/%s", post.PlatformPostID), params)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch tweet metrics: %w", err)
	}

	var metrics []*socialmedia.PostMetrics

	if tweetData, ok := data["data"].(map[string]interface{}); ok {
		metric := &socialmedia.PostMetrics{
			PostID:     post.ID,
			MetricDate: time.Now(), // Twitter doesn't provide historical daily metrics easily
			RawData:    tweetData,
		}

		// Public metrics (available in free tier)
		if publicMetrics, ok := tweetData["public_metrics"].(map[string]interface{}); ok {
			if likes, ok := publicMetrics["like_count"].(float64); ok {
				metric.Likes = int64(likes)
			}
			if retweets, ok := publicMetrics["retweet_count"].(float64); ok {
				metric.Retweets = int64(retweets)
			}
			if replies, ok := publicMetrics["reply_count"].(float64); ok {
				metric.Replies = int64(replies)
			}
			if quotes, ok := publicMetrics["quote_count"].(float64); ok {
				metric.QuoteTweets = int64(quotes)
			}
		}

		// Non-public metrics (requires Basic tier)
		if nonPublicMetrics, ok := tweetData["non_public_metrics"].(map[string]interface{}); ok {
			if impressions, ok := nonPublicMetrics["impression_count"].(float64); ok {
				metric.Impressions = int64(impressions)
			}
		}

		// Organic metrics (requires Basic tier)
		if organicMetrics, ok := tweetData["organic_metrics"].(map[string]interface{}); ok {
			if impressions, ok := organicMetrics["impression_count"].(float64); ok {
				metric.Impressions = int64(impressions)
			}
			if likes, ok := organicMetrics["like_count"].(float64); ok {
				metric.Likes = int64(likes)
			}
		}

		metrics = append(metrics, metric)
	}

	return metrics, nil
}

// FetchAccountMetrics fetches aggregate metrics for the Twitter account
func (s *TwitterScraper) FetchAccountMetrics(ctx context.Context, account *socialmedia.Account, startDate, endDate time.Time) ([]*socialmedia.AccountMetrics, error) {
	params := url.Values{}
	params.Add("user.fields", "public_metrics")

	data, err := s.makeRequest(ctx, fmt.Sprintf("users/%s", account.PlatformAccountID), params)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch account metrics: %w", err)
	}

	metric := &socialmedia.AccountMetrics{
		AccountID:  account.ID,
		MetricDate: time.Now(),
		RawData:    data,
	}

	if userData, ok := data["data"].(map[string]interface{}); ok {
		if publicMetrics, ok := userData["public_metrics"].(map[string]interface{}); ok {
			if followers, ok := publicMetrics["followers_count"].(float64); ok {
				followersTotal := int64(followers)
				metric.FollowersTotal = &followersTotal
			}
			if following, ok := publicMetrics["following_count"].(float64); ok {
				followingTotal := int64(following)
				metric.FollowingTotal = &followingTotal
			}
			if tweetCount, ok := publicMetrics["tweet_count"].(float64); ok {
				metric.TweetsPosted = int(tweetCount)
			}
		}
	}

	return []*socialmedia.AccountMetrics{metric}, nil
}

// FetchComments fetches replies to a tweet
func (s *TwitterScraper) FetchComments(ctx context.Context, post *socialmedia.Post) ([]*socialmedia.Comment, error) {
	// To fetch replies, we need to search for tweets that reference the original tweet
	params := url.Values{}
	params.Add("query", fmt.Sprintf("conversation_id:%s", post.PlatformPostID))
	params.Add("tweet.fields", "id,text,author_id,created_at,public_metrics,referenced_tweets")
	params.Add("max_results", "100")

	data, err := s.makeRequest(ctx, "tweets/search/recent", params)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch replies: %w", err)
	}

	var comments []*socialmedia.Comment

	if items, ok := data["data"].([]interface{}); ok {
		for _, item := range items {
			if tweet, ok := item.(map[string]interface{}); ok {
				comment := &socialmedia.Comment{
					PostID: post.ID,
				}

				if id, ok := tweet["id"].(string); ok {
					comment.PlatformCommentID = id
				}
				if text, ok := tweet["text"].(string); ok {
					comment.CommentText = text
				}
				if authorID, ok := tweet["author_id"].(string); ok {
					comment.AuthorID = authorID
				}
				if createdAt, ok := tweet["created_at"].(string); ok {
					if t, err := time.Parse(time.RFC3339, createdAt); err == nil {
						comment.PublishedAt = t
					}
				}
				if publicMetrics, ok := tweet["public_metrics"].(map[string]interface{}); ok {
					if likes, ok := publicMetrics["like_count"].(float64); ok {
						comment.LikesCount = int(likes)
					}
					if replies, ok := publicMetrics["reply_count"].(float64); ok {
						comment.ReplyCount = int(replies)
					}
				}

				comments = append(comments, comment)
			}
		}
	}

	return comments, nil
}
