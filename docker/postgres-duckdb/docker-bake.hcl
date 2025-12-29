variable "REGISTRY" {
  default = "ghcr.io"
}

variable "REPO" {
  default = "soypete/postgres-duckdb"
}

variable "TAG" {
  default = "16"
}

group "default" {
  targets = ["postgres-duckdb"]
}

target "postgres-duckdb" {
  context    = "."
  dockerfile = "Dockerfile"
  tags = [
    "${REGISTRY}/${REPO}:${TAG}",
    "${REGISTRY}/${REPO}:latest"
  ]
  platforms = ["linux/amd64", "linux/arm64"]
  cache-from = ["type=gha"]
  cache-to   = ["type=gha,mode=max"]
}
