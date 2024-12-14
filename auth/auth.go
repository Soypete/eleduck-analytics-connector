package auth

import (
	"context"
	"sync"

	"github.com/pkg/errors"
	"golang.org/x/oauth2"
)

// Credentials is a struct that holds the credentials for any analytics service.
type Credentials struct {
	TwitchAuth  string
	TwitchToken *oauth2.Token
	TwitchID    string
	wg          *sync.WaitGroup
}

// SetupCredentials returns a new Credentials struct.
func SetupCredentials(wg *sync.WaitGroup) (*Credentials, error) {
	c := &Credentials{
		wg: wg,
	}

	// reset context so that timeout is not tied to other api calls.
	ctx := context.Background()
	err := c.AuthTwitch(ctx)
	if err != nil {
		return nil, errors.Wrap(err, "failed to authenticate with twitch")
	}

	return c, nil
}
