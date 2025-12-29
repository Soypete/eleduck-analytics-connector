.PHONY: help build-postgres push-postgres deploy destroy psql logs-postgres port-forward-postgres \
	build-dbt push-dbt dbt-build dbt-run dbt-test dbt-seed dbt-logs generate-dim-date

NAMESPACE := eleduck-analytics
POSTGRES_POD := $(shell kubectl get pods -n $(NAMESPACE) -l app=postgres -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

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

# Status checks
status: ## Show status of all pods
	kubectl get pods -n $(NAMESPACE)

secrets: ## List secrets in namespace
	kubectl get secrets -n $(NAMESPACE)

describe-postgres: ## Describe postgres deployment
	kubectl describe deployment -n $(NAMESPACE) postgres

# DBT operations
build-dbt: ## Build DBT Docker image
	docker build -t ghcr.io/soypete/eleduck-dbt:latest -f docker/dbt/Dockerfile .

push-dbt: ## Push DBT Docker image
	docker push ghcr.io/soypete/eleduck-dbt:latest

dbt-build: ## Run dbt build via Kubernetes job
	kubectl delete job dbt-manual -n $(NAMESPACE) --ignore-not-found
	kubectl apply -f k8s/dbt/job-manual.yaml
	kubectl wait --for=condition=complete job/dbt-manual -n $(NAMESPACE) --timeout=600s
	kubectl logs job/dbt-manual -n $(NAMESPACE)

dbt-run: ## Run dbt run via Kubernetes job
	kubectl delete job dbt-manual -n $(NAMESPACE) --ignore-not-found
	sed 's/build/run/' k8s/dbt/job-manual.yaml | kubectl apply -f -
	kubectl wait --for=condition=complete job/dbt-manual -n $(NAMESPACE) --timeout=600s

dbt-test: ## Run dbt test via Kubernetes job
	kubectl delete job dbt-manual -n $(NAMESPACE) --ignore-not-found
	sed 's/build/test/' k8s/dbt/job-manual.yaml | kubectl apply -f -
	kubectl wait --for=condition=complete job/dbt-manual -n $(NAMESPACE) --timeout=300s

dbt-seed: ## Run dbt seed (load dim_date, etc.)
	kubectl delete job dbt-manual -n $(NAMESPACE) --ignore-not-found
	sed 's/build/seed/' k8s/dbt/job-manual.yaml | kubectl apply -f -
	kubectl wait --for=condition=complete job/dbt-manual -n $(NAMESPACE) --timeout=300s

dbt-logs: ## View latest DBT job logs
	kubectl logs -l job-name=dbt-manual -n $(NAMESPACE)

generate-dim-date: ## Generate dim_date seed CSV
	python scripts/generate_dim_date.py
