package postgres

import (
	"fmt"
	"time"

	"github.com/lib/pq"
)

// StreamsResponse is the response from the Twitch API for the streams endpoint
type StreamsResponse struct {
	Data       []Data `json:"data"`
	Pagination struct {
		Cursor string `json:"cursor"`
	} `json:"pagination"`
}

// it seems that you cannot do a named exec on a json tags first
type Data struct {
	ID           string    `json:"id",db:"id"`
	Source       string    `db:"source"` // this is set in the go code
	UserID       string    `json:"user_id",db:"user_id"`
	UserLogin    string    `json:"user_login",db:"user_login"`
	UserName     string    `json:"user_name",db:"user_name`
	GameID       string    `json:"game_id",db:"game_id"`
	GameName     string    `json:"game_name",db:"game_name"`
	Type         string    `json:"type",db:"type`
	Title        string    `json:"title",db:"title`
	Viewers      int       `json:"viewer_count",db:"viewer_count`
	StartedAt    time.Time `json:"started_at",db:"started_at`
	Language     string    `json:"language",db:"language`
	ThumbnailURL string    `json:"thumbnail_url",db:"thumbnail_url`
	TagIds       []any     `json:"tag_ids",db:"tag_ids`
	Tags         []string  `json:"tags",db:"tags`
	IsMature     bool      `json:"is_mature",db:"is_mature`
}

// UpsertStreamInfo creates a new stream record if it doesn't exist, otherwise it does nothing.
func (db *DB) UpsertStreamInfo(streams StreamsResponse) error {
	query := `Insert into streams (
							source,
							source_id,
							user_id, 
							user_login, 
							user_name, 
							game_id, 
							game_name, 
							category, 
							title, 
							started_at, 
							language, 
							thumbnail_url, 
							tag_ids,
							tags, 
							is_mature) 
						values (
							$1,
							$2,
							$3,
							$4,
							$5,
							$6,
							$7,
							$8,
							$9,
							$10,
							$11,
							$12,
							$13,
							$14,
							$15
							)
						ON CONFLICT (source_id) 
							do nothing;`

	tags := pq.StringArray(streams.Data[0].Tags)
	var tagIDs []string
	for _, tag := range streams.Data[0].TagIds {
		t, ok := tag.(string)
		if !ok {
			continue
		}
		tagIDs = append(tagIDs, t)
	}

	_, err := db.Exec(query, streams.Data[0].Source, streams.Data[0].ID, streams.Data[0].UserID, streams.Data[0].UserLogin, streams.Data[0].UserName, streams.Data[0].GameID, streams.Data[0].GameName, streams.Data[0].Type, streams.Data[0].Title, streams.Data[0].StartedAt, streams.Data[0].Language, streams.Data[0].ThumbnailURL, pq.StringArray(tagIDs), tags, streams.Data[0].IsMature)
	if err != nil {
		return fmt.Errorf("failed to insert stream data: %w", err)
	}
	return nil
}
