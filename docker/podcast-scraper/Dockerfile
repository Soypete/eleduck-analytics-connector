# Build stage
FROM golang:1.22-alpine AS builder

WORKDIR /app

# Install build dependencies
RUN apk add --no-cache git ca-certificates

# Copy go mod files
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

# Copy source code
COPY . .

# Build the application
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags="-w -s" \
    -o /app/podcast-scraper \
    ./cmd/podcast-scraper

# Runtime stage
FROM alpine:3.19

WORKDIR /app

# Install runtime dependencies
RUN apk add --no-cache ca-certificates tzdata

# Copy binary from builder
COPY --from=builder /app/podcast-scraper /app/podcast-scraper

# Create non-root user
RUN addgroup -g 1000 scraper && \
    adduser -D -u 1000 -G scraper scraper

USER scraper

ENTRYPOINT ["/app/podcast-scraper"]
