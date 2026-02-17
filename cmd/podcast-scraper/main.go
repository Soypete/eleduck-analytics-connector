package main

import (
	"context"
	"database/sql"
	"fmt"
	"log"
	"net/url"
	"os"
	"os/signal"
	"syscall"
	"time"

	_ "github.com/lib/pq"
	"github.com/soypete/eleduck-analytics-connector/internal/repository"
	"github.com/soypete/eleduck-analytics-connector/internal/scrapers"
	"github.com/soypete/eleduck-analytics-connector/internal/scrapers/amazon"
	"github.com/soypete/eleduck-analytics-connector/internal/scrapers/apple"
	"github.com/soypete/eleduck-analytics-connector/internal/scrapers/spotify"
	"github.com/soypete/eleduck-analytics-connector/internal/scrapers/youtube"
)

func main() {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// Handle graceful shutdown
	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, os.Interrupt, syscall.SIGTERM)
	go func() {
		<-sigCh
		log.Println("Received shutdown signal, stopping...")
		cancel()
	}()

	// Load configuration from environment
	config := loadConfig()

	// Connect to database
	db, err := connectDatabase(config)
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}
	defer db.Close()

	// Initialize repository
	repo := repository.NewPodcastRepository(db)

	// Initialize scrapers
	scraperInstances, err := initializeScrapers(config)
	if err != nil {
		log.Fatalf("Failed to initialize scrapers: %v", err)
	}

	// Run metrics collection
	collector := NewCollector(repo, scraperInstances)

	// Determine run mode: one-time or scheduled
	runMode := getEnv("RUN_MODE", "once")

	if runMode == "scheduled" {
		// Run on a schedule (e.g., daily at midnight)
		scheduleInterval := getEnvDuration("SCHEDULE_INTERVAL", 24*time.Hour)
		runScheduled(ctx, collector, scheduleInterval)
	} else {
		// Run once and exit
		if err := collector.CollectAll(ctx); err != nil {
			log.Fatalf("Collection failed: %v", err)
		}
		log.Println("Collection completed successfully")
	}
}

// Config holds application configuration
type Config struct {
	DatabaseURL string
	ShowName    string

	// Apple Podcasts credentials
	AppleEmail    string
	ApplePassword string

	// Spotify credentials (cookies)
	SpotifySpCookie    string
	SpotifySpKeyCookie string

	// Amazon Music credentials
	AmazonSessionCookie string

	// YouTube credentials
	YouTubeAPIKey      string
	YouTubeAccessToken string
}

// loadConfig loads configuration from environment variables
func loadConfig() *Config {
	return &Config{
		DatabaseURL:         getEnv("DATABASE_URL", ""),
		ShowName:            getEnv("SHOW_NAME", "domesticating ai"),
		AppleEmail:          getEnv("APPLE_PODCASTS_EMAIL", ""),
		ApplePassword:       getEnv("APPLE_PODCASTS_PASSWORD", ""),
		SpotifySpCookie:     getEnv("SPOTIFY_SP_COOKIE", ""),
		SpotifySpKeyCookie:  getEnv("SPOTIFY_SP_KEY_COOKIE", ""),
		AmazonSessionCookie: getEnv("AMAZON_SESSION_COOKIE", ""),
		YouTubeAPIKey:       getEnv("YOUTUBE_API_KEY", ""),
		YouTubeAccessToken:  getEnv("YOUTUBE_ACCESS_TOKEN", ""),
	}
}

// connectDatabase connects to the PostgreSQL database
func connectDatabase(config *Config) (*sql.DB, error) {
	dbURL := config.DatabaseURL
	if dbURL == "" {
		// Build from components
		params := url.Values{}
		params.Set("sslmode", getEnv("DB_SSL_MODE", "require"))

		dbURL = (&url.URL{
			Scheme:   "postgresql",
			User:     url.UserPassword(getEnv("DB_USER", "postgres"), getEnv("DB_PASSWORD", "")),
			Host:     fmt.Sprintf("%s:%s", getEnv("DB_HOST", "localhost"), getEnv("DB_PORT", "5432")),
			Path:     getEnv("DB_NAME", "analytics"),
			RawQuery: params.Encode(),
		}).String()
	}

	db, err := sql.Open("postgres", dbURL)
	if err != nil {
		return nil, fmt.Errorf("failed to open database: %w", err)
	}

	// Test connection
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	if err := db.PingContext(ctx); err != nil {
		return nil, fmt.Errorf("failed to ping database: %w", err)
	}

	// Set connection pool settings
	db.SetMaxOpenConns(25)
	db.SetMaxIdleConns(5)
	db.SetConnMaxLifetime(5 * time.Minute)

	log.Println("Database connection established")
	return db, nil
}

// initializeScrapers creates all scraper instances
func initializeScrapers(config *Config) ([]scrapers.Scraper, error) {
	var scraperList []scrapers.Scraper

	// Apple Podcasts scraper
	if config.AppleEmail != "" && config.ApplePassword != "" {
		appleScraper, err := apple.NewScraper(apple.Config{
			Email:    config.AppleEmail,
			Password: config.ApplePassword,
		})
		if err != nil {
			return nil, fmt.Errorf("failed to create Apple Podcasts scraper: %w", err)
		}
		scraperList = append(scraperList, appleScraper)
		log.Println("Initialized Apple Podcasts scraper")
	} else {
		log.Println("Skipping Apple Podcasts scraper (credentials not provided)")
	}

	// Spotify scraper
	if config.SpotifySpCookie != "" {
		spotifyScraper, err := spotify.NewScraper(spotify.Config{
			SpCookie:    config.SpotifySpCookie,
			SpKeyCookie: config.SpotifySpKeyCookie,
		})
		if err != nil {
			return nil, fmt.Errorf("failed to create Spotify scraper: %w", err)
		}
		scraperList = append(scraperList, spotifyScraper)
		log.Println("Initialized Spotify scraper")
	} else {
		log.Println("Skipping Spotify scraper (credentials not provided)")
	}

	// Amazon Music scraper
	if config.AmazonSessionCookie != "" {
		amazonScraper, err := amazon.NewScraper(amazon.Config{
			SessionCookie: config.AmazonSessionCookie,
		})
		if err != nil {
			return nil, fmt.Errorf("failed to create Amazon Music scraper: %w", err)
		}
		scraperList = append(scraperList, amazonScraper)
		log.Println("Initialized Amazon Music scraper")
	} else {
		log.Println("Skipping Amazon Music scraper (credentials not provided)")
	}

	// YouTube scraper
	if config.YouTubeAPIKey != "" || config.YouTubeAccessToken != "" {
		youtubeScraper, err := youtube.NewScraper(youtube.Config{
			APIKey:      config.YouTubeAPIKey,
			AccessToken: config.YouTubeAccessToken,
		})
		if err != nil {
			return nil, fmt.Errorf("failed to create YouTube scraper: %w", err)
		}
		scraperList = append(scraperList, youtubeScraper)
		log.Println("Initialized YouTube scraper")
	} else {
		log.Println("Skipping YouTube scraper (credentials not provided)")
	}

	if len(scraperList) == 0 {
		return nil, fmt.Errorf("no scrapers initialized - check credentials")
	}

	return scraperList, nil
}

// Collector orchestrates metrics collection across all platforms
type Collector struct {
	repo     *repository.PodcastRepository
	scrapers []scrapers.Scraper
}

// NewCollector creates a new collector
func NewCollector(repo *repository.PodcastRepository, scrapers []scrapers.Scraper) *Collector {
	return &Collector{
		repo:     repo,
		scrapers: scrapers,
	}
}

// CollectAll runs collection for all scrapers
func (c *Collector) CollectAll(ctx context.Context) error {
	showName := getEnv("SHOW_NAME", "domesticating ai")
	lookbackDays := getEnvInt("LOOKBACK_DAYS", 30)

	startDate := time.Now().AddDate(0, 0, -lookbackDays)
	endDate := time.Now()

	for _, scraper := range c.scrapers {
		if err := c.collectForPlatform(ctx, scraper, showName, startDate, endDate); err != nil {
			log.Printf("Error collecting from %s: %v", scraper.GetPlatform(), err)
			// Continue with other platforms even if one fails
			continue
		}
	}

	return nil
}

// collectForPlatform collects metrics for a single platform
func (c *Collector) collectForPlatform(ctx context.Context, scraper scrapers.Scraper, showName string, startDate, endDate time.Time) error {
	platform := scraper.GetPlatform()
	log.Printf("Starting collection for %s", platform)

	// Record scraper run
	run := &scrapers.ScraperRun{
		Platform:     platform,
		RunStartedAt: time.Now(),
		Status:       "running",
	}

	runID, err := c.repo.RecordScraperRun(ctx, run)
	if err != nil {
		return fmt.Errorf("failed to record scraper run: %w", err)
	}

	defer func() {
		completedAt := time.Now()
		run.RunCompletedAt = &completedAt

		if err := c.repo.UpdateScraperRun(ctx, runID, run); err != nil {
			log.Printf("Failed to update scraper run: %v", err)
		}
	}()

	// Fetch podcast info
	podcast, err := scraper.FetchPodcastInfo(ctx, showName)
	if err != nil {
		run.Status = "failed"
		errMsg := err.Error()
		run.ErrorMessage = &errMsg
		return fmt.Errorf("failed to fetch podcast info: %w", err)
	}

	// Upsert podcast to database
	podcastID, err := c.repo.UpsertPodcast(ctx, podcast)
	if err != nil {
		run.Status = "failed"
		errMsg := err.Error()
		run.ErrorMessage = &errMsg
		return fmt.Errorf("failed to upsert podcast: %w", err)
	}
	podcast.ID = podcastID

	// Fetch episodes
	episodes, err := scraper.FetchEpisodes(ctx, podcast)
	if err != nil {
		run.Status = "failed"
		errMsg := err.Error()
		run.ErrorMessage = &errMsg
		return fmt.Errorf("failed to fetch episodes: %w", err)
	}

	log.Printf("Found %d episodes for %s on %s", len(episodes), showName, platform)

	// Process each episode
	for _, episode := range episodes {
		episode.PodcastID = podcastID

		// Upsert episode
		episodeID, err := c.repo.UpsertEpisode(ctx, episode)
		if err != nil {
			log.Printf("Failed to upsert episode %s: %v", episode.EpisodeTitle, err)
			continue
		}
		episode.ID = episodeID

		// Fetch episode metrics
		episodeMetrics, err := scraper.FetchEpisodeMetrics(ctx, episode, startDate, endDate)
		if err != nil {
			log.Printf("Failed to fetch metrics for episode %s: %v", episode.EpisodeTitle, err)
			continue
		}

		// Store metrics
		for _, metric := range episodeMetrics {
			metric.EpisodeID = episodeID
			if err := c.repo.UpsertEpisodeMetrics(ctx, metric); err != nil {
				log.Printf("Failed to store metrics for episode %s: %v", episode.EpisodeTitle, err)
				continue
			}
			run.MetricsCollected++
		}

		// Fetch comments (if platform supports it)
		comments, err := scraper.FetchComments(ctx, episode)
		if err != nil {
			log.Printf("Failed to fetch comments for episode %s: %v", episode.EpisodeTitle, err)
		} else {
			for _, comment := range comments {
				if err := c.repo.InsertComment(ctx, comment); err != nil {
					log.Printf("Failed to store comment: %v", err)
				}
			}
		}

		run.EpisodesProcessed++
	}

	// Fetch show-level metrics
	showMetrics, err := scraper.FetchShowMetrics(ctx, podcast, startDate, endDate)
	if err != nil {
		log.Printf("Failed to fetch show metrics: %v", err)
	} else {
		for _, metric := range showMetrics {
			metric.PodcastID = podcastID
			if err := c.repo.UpsertShowMetrics(ctx, metric); err != nil {
				log.Printf("Failed to store show metrics: %v", err)
			}
		}
	}

	run.Status = "completed"
	log.Printf("Completed collection for %s: %d episodes, %d metrics", platform, run.EpisodesProcessed, run.MetricsCollected)

	return nil
}

// runScheduled runs the collector on a schedule
func runScheduled(ctx context.Context, collector *Collector, interval time.Duration) {
	ticker := time.NewTicker(interval)
	defer ticker.Stop()

	// Run immediately on startup
	if err := collector.CollectAll(ctx); err != nil {
		log.Printf("Collection failed: %v", err)
	}

	for {
		select {
		case <-ctx.Done():
			log.Println("Scheduled collection stopped")
			return
		case <-ticker.C:
			if err := collector.CollectAll(ctx); err != nil {
				log.Printf("Collection failed: %v", err)
			}
		}
	}
}

// getEnv gets an environment variable with a default value
func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

// getEnvInt gets an environment variable as int with a default value
func getEnvInt(key string, defaultValue int) int {
	if value := os.Getenv(key); value != "" {
		var intVal int
		if _, err := fmt.Sscanf(value, "%d", &intVal); err == nil {
			return intVal
		}
	}
	return defaultValue
}

// getEnvDuration gets an environment variable as duration with a default value
func getEnvDuration(key string, defaultValue time.Duration) time.Duration {
	if value := os.Getenv(key); value != "" {
		if duration, err := time.ParseDuration(value); err == nil {
			return duration
		}
	}
	return defaultValue
}
