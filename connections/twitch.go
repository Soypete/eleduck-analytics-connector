package connections

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"net/http"
	"net/url"
	"time"

	"github.com/soypete/eleduck-analytics-connector/auth"
	"github.com/soypete/eleduck-analytics-connector/persistance/postgres"
)

type TwitchClient struct {
	auth *auth.Credentials
	path url.URL
	db   *postgres.DB
}

// NewTwitchClient returns a new TwitchClient
func NewTwitchClient(auth *auth.Credentials, db *postgres.DB) *TwitchClient {
	path := url.URL{
		Scheme: "https",
		Host:   "api.twitch.tv",
		Path:   "helix",
	}

	return &TwitchClient{
		auth: auth,
		path: path,
		db:   db,
	}
}

func (c TwitchClient) FetchStreamCount() error {
	const twitchStreamsApi = "/streams"

	apiClient := &http.Client{
		Timeout: time.Second * 10,
	}

	params := url.Values{}
	params.Set("user_login", "soypetetech")

	path := c.path // copy the path so we don't modify the original

	path.Path = c.path.Path + twitchStreamsApi
	path.RawQuery = params.Encode()

	req, err := http.NewRequest("GET", path.String(), nil)
	if err != nil {
		return fmt.Errorf("failed to create request: %w", err)
	}
	req.Header.Set("Client-ID", c.auth.TwitchID)
	req.Header.Set("Authorization", "Bearer "+c.auth.TwitchToken.AccessToken)

	// while live (do a live check)
	// wait 15 min and pull stream to get viewer count?
	resp, err := apiClient.Do(req)
	if err != nil {
		return fmt.Errorf("failed to make request: %w", err)
	}

	if resp.StatusCode >= 300 {

		return fmt.Errorf("bad response from twitch api: %d", resp.StatusCode)
	}

	defer resp.Body.Close()
	body, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		return fmt.Errorf("failed to read response body: %w", err)
	}

	streamData := postgres.StreamsResponse{}
	err = json.Unmarshal(body, &streamData)
	if err != nil {
		return fmt.Errorf("failed to unmarshal response body: %w", err)
	}

	if len(streamData.Data) == 0 {
		return fmt.Errorf("no streams found")
	}

	streamData.Data[0].Source = "twitch"
	// send to db
	err = c.db.UpsertStreamInfo(streamData)
	if err != nil {
		return fmt.Errorf("failed to upsert stream info: %w", err)
	}
	return nil
}
