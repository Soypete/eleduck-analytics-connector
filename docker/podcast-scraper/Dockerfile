FROM golang:1.22-alpine AS builder

WORKDIR /app

# Copy go mod files
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY cmd/ ./cmd/
COPY internal/ ./internal/

# Build the podcast scraper
RUN CGO_ENABLED=0 GOOS=linux go build -o podcast-scraper ./cmd/podcast-scraper

# Runtime image
FROM alpine:latest

RUN apk --no-cache add ca-certificates

WORKDIR /root/

# Copy the binary from builder
COPY --from=builder /app/podcast-scraper .

# Run as non-root user
RUN adduser -D -u 1000 scraper
USER scraper

ENTRYPOINT ["./podcast-scraper"]
