package auth

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"time"

	"golang.org/x/oauth2"
	"golang.org/x/oauth2/twitch"
)

func (c *Credentials) parseAuthCode(w http.ResponseWriter, req *http.Request) {
	err := req.ParseForm()
	if err != nil {
		// This is a bad pattern because it will return a full error history with the %w. Sometimes
		// secrets are included in the error message.
		err = fmt.Errorf("could not parse query: %w", err)
		http.Error(w, err.Error(), http.StatusBadRequest)
	}
	c.TwitchAuth = req.FormValue("code")
}

// AuthTwitch use oauth2 protocol to retrieve oauth2 token for twitch IRC.
// _NOTE_: this has not been tested on long standing projects.
func (c *Credentials) AuthTwitch(ctx context.Context) error {
	http.HandleFunc("/oauth/redirect", c.parseAuthCode)
	go func() {
		err := http.ListenAndServe("localhost:3000", nil)
		if err != nil {
			log.Fatalf("could not start server to auth twitch: %v", err)
		}
	}()

	c.TwitchID = os.Getenv("TWITCH_ID")
	conf := &oauth2.Config{
		// TODO: use const for the following.
		ClientID:     c.TwitchID,
		ClientSecret: os.Getenv("TWITCH_SECRET"),
		Scopes:       []string{"bits:read", "channel:read:ads", "channel:read:charity", "channel:read:editors", "channel:read:goals", "channel:read:guest_star", "channel:read:hype_train", "channel:read:polls", "channel:read:predictions", "channel:read:redemptions", "channel:read:subscriptions", "channel:read:vips", "moderator:read:banned_users", "moderator:read:blocked_terms", "moderator:read:chat_messages", "moderator:read:chatters", "moderator:read:followers", "moderator:read:shoutouts"},
		RedirectURL:  "http://localhost:3000/oauth/redirect",
		Endpoint:     twitch.Endpoint,
	}

	c.wg.Add(1)

	// Redirect user to consent page to ask for permission
	// for the scopes specified above.
	go func() {
		defer c.wg.Done()
		url := conf.AuthCodeURL("state", oauth2.AccessTypeOffline)

		// this print is needed for the user to provide the auth code.
		fmt.Printf("Visit the URL for the auth dialog: %v\n", url)
		for c.TwitchAuth == "" {
			time.Sleep(1 * time.Second)
		}
		var err error
		c.TwitchToken, err = conf.Exchange(ctx, c.TwitchAuth)
		if err != nil {
			// print until we have ctx.done
			fmt.Println(fmt.Errorf("failed to get token with auth code: %w", err))
		}
	}()
	return nil
}
