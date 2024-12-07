package main

import (
	"fmt"
	"sync"

	"github.com/soypete/eleduck-analytics-connector/auth"
	"github.com/soypete/eleduck-analytics-connector/connections"
	"github.com/soypete/eleduck-analytics-connector/persistance/postgres"
)

func main() {

	wg := new(sync.WaitGroup)
	// setup db connection
	db, err := postgres.Setup(wg)
	if err != nil {
		panic(err)
	}

	// Setup the twitch client
	creds, err := auth.SetupCredentials(wg)
	if err != nil {
		panic(err)
	}

	wg.Wait()

	fmt.Println("ready to call")
	twitchCaller := connections.NewTwitchClient(creds, db)
	err = twitchCaller.FetchStreamCount()
	if err != nil {
		panic(err)
	}
	fmt.Println("done")
}
