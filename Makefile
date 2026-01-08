.PHONY: help build-postgres push-postgres deploy destroy psql logs-postgres port-forward-postgres
.PHONY: dbt-run dbt-test dbt-seed dbt-docs port-forward-airbyte port-forward-metabase logs-airbyte logs-metabase

NAMESPACE := eleduck-analytics
POSTGRES_POD := $(shell kubectl get pods -n $(NAMESPACE) -l app=postgres -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
AIRBYTE_POD := $(shell kubectl get pods -n $(NAMESPACE) -l app=airbyte,component=server -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
METABASE_POD := $(shell kubectl get pods -n $(NAMESPACE) -l app=metabase -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-25s\033[0m %s\n", $$1, $$2}'

# Docker builds
build-postgres: ## Build postgres-duckdb Docker image
	cd docker/postgres-duckdb && docker buildx bake -f docker-bake.hcl

push-postgres: ## Push postgres-duckdb Docker image to GHCR
	cd docker/postgres-duckdb && docker buildx bake -f docker-bake.hcl --push

# Kubernetes operations
deploy: ## Deploy all infrastructure to Kubernetes
	kubectl apply -k k8s/

destroy: ## Remove all infrastructure from Kubernetes
	kubectl delete -k k8s/ --ignore-not-found

# PostgreSQL operations
psql: ## Connect to PostgreSQL via kubectl exec
	@if [ -z "$(POSTGRES_POD)" ]; then echo "No postgres pod found"; exit 1; fi
	kubectl exec -it -n $(NAMESPACE) $(POSTGRES_POD) -- psql -U $$(kubectl get secret -n $(NAMESPACE) postgres-credentials -o jsonpath='{.data.username}' | base64 -d) -d $$(kubectl get secret -n $(NAMESPACE) postgres-credentials -o jsonpath='{.data.database}' | base64 -d)

logs-postgres: ## Tail PostgreSQL logs
	kubectl logs -f -n $(NAMESPACE) -l app=postgres

port-forward-postgres: ## Port forward PostgreSQL to localhost:5432
	kubectl port-forward -n $(NAMESPACE) svc/postgres 5432:5432

# DBT operations
dbt-deps: ## Install DBT dependencies
	cd dbt && dbt deps

dbt-seed: ## Load seed data (content mapping)
	cd dbt && dbt seed --profiles-dir .

dbt-run: ## Run all DBT models
	cd dbt && dbt run --profiles-dir .

dbt-test: ## Run DBT tests
	cd dbt && dbt test --profiles-dir .

dbt-build: ## Run DBT build (seed + run + test)
	cd dbt && dbt build --profiles-dir .

dbt-docs: ## Generate and serve DBT documentation
	cd dbt && dbt docs generate --profiles-dir . && dbt docs serve --profiles-dir .

dbt-clean: ## Clean DBT artifacts
	cd dbt && dbt clean

# Airbyte operations
logs-airbyte: ## Tail Airbyte server logs
	kubectl logs -f -n $(NAMESPACE) -l app=airbyte,component=server

logs-airbyte-worker: ## Tail Airbyte worker logs
	kubectl logs -f -n $(NAMESPACE) -l app=airbyte,component=worker

port-forward-airbyte: ## Port forward Airbyte webapp to localhost:8000
	kubectl port-forward -n $(NAMESPACE) svc/airbyte-webapp 8000:80

describe-airbyte: ## Describe Airbyte deployments
	kubectl describe deployment -n $(NAMESPACE) -l app=airbyte

# Metabase operations
logs-metabase: ## Tail Metabase logs
	kubectl logs -f -n $(NAMESPACE) -l app=metabase

port-forward-metabase: ## Port forward Metabase to localhost:3000
	kubectl port-forward -n $(NAMESPACE) svc/metabase 3000:3000

describe-metabase: ## Describe Metabase deployment
	kubectl describe deployment -n $(NAMESPACE) metabase

# Status checks
status: ## Show status of all pods
	kubectl get pods -n $(NAMESPACE)

status-all: ## Show status of all resources
	@echo "=== Pods ===" && kubectl get pods -n $(NAMESPACE)
	@echo "\n=== Services ===" && kubectl get svc -n $(NAMESPACE)
	@echo "\n=== PVCs ===" && kubectl get pvc -n $(NAMESPACE)
	@echo "\n=== Secrets ===" && kubectl get secrets -n $(NAMESPACE)

secrets: ## List secrets in namespace
	kubectl get secrets -n $(NAMESPACE)

describe-postgres: ## Describe postgres deployment
	kubectl describe deployment -n $(NAMESPACE) postgres

# Full pipeline operations
pipeline-run: ## Run full data pipeline: Airbyte sync → DBT build
	@echo "Starting Airbyte sync..."
	@echo "Note: Trigger sync from Airbyte UI at localhost:8000"
	@echo "After sync completes, run DBT..."
	cd dbt && dbt build --profiles-dir .

# Local development
dev-setup: ## Set up local development environment
	@echo "Setting up local development..."
	@echo "1. Install Python dependencies for DBT"
	pip install dbt-postgres
	@echo "2. Port forward PostgreSQL"
	@echo "Run: make port-forward-postgres"
	@echo "3. Set environment variables"
	@echo "export DBT_POSTGRES_HOST=localhost"
	@echo "export DBT_POSTGRES_PORT=5432"
	@echo "export DBT_POSTGRES_USER=<your-user>"
	@echo "export DBT_POSTGRES_PASSWORD=<your-password>"
	@echo "export DBT_POSTGRES_DATABASE=eleduck"
