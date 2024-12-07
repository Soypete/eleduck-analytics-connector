package postgres

import (
	"embed"
	"fmt"
	"net/url"
	"os"
	"sync"

	"github.com/jmoiron/sqlx"
	_ "github.com/lib/pq"
	"github.com/pressly/goose/v3"
)

//go:embed migrations/*.sql
var embedMigrations embed.FS

type DB struct {
	*sqlx.DB
}

func Setup(wg *sync.WaitGroup) (*DB, error) {
	params := url.Values{}
	params.Set("sslmode", "disable")

	// this is a personal preference to use url.URL to
	// build up the connection string. This works well for
	// postgres, but other drivers might have their own quirks.
	connectionString := url.URL{
		Scheme:   "postgresql",
		User:     url.UserPassword(os.Getenv("POSTGRES_USER"), os.Getenv("POSTGRES_PASSWORD")),
		Host:     os.Getenv("POSTGRES_HOST"),
		Path:     os.Getenv("POSTGRES_DB"),
		RawQuery: params.Encode(),
	}

	db, err := sqlx.Connect("postgres", connectionString.String())
	if err != nil {
		return nil, fmt.Errorf("failed to connect to database: %w", err)
	}
	wg.Add(1)
	go func() {
		defer wg.Done() // will stop the main function until after the migrations are run.
		goose.SetBaseFS(embedMigrations)

		if err := goose.SetDialect("postgres"); err != nil {
			panic(err)
		}

		if err := goose.Up(db.DB, "migrations"); err != nil {
			panic(err)
		}
	}()

	return &DB{db}, nil
}
