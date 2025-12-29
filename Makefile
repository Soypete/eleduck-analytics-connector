.PHONY: help build-postgres push-postgres deploy destroy psql logs-postgres port-forward-postgres \
	deploy-airbyte uninstall-airbyte port-forward-airbyte logs-airbyte-server logs-airbyte-worker airbyte-pods \
	build-sqlmesh push-sqlmesh sqlmesh-plan sqlmesh-run sqlmesh-audit sqlmesh-logs generate-dim-date

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

# Airbyte operations
deploy-airbyte: ## Deploy Airbyte via Helm
	helm repo add airbyte https://airbytehq.github.io/helm-charts || true
	helm repo update
	helm upgrade --install airbyte airbyte/airbyte \
		-f k8s/airbyte/values.yaml \
		-n $(NAMESPACE) \
		--wait --timeout 10m

uninstall-airbyte: ## Uninstall Airbyte
	helm uninstall airbyte -n $(NAMESPACE) || true

port-forward-airbyte: ## Port forward Airbyte UI to localhost:8080
	@echo "Airbyte UI available at http://localhost:8080"
	kubectl port-forward svc/airbyte-airbyte-webapp-svc 8080:80 -n $(NAMESPACE)

logs-airbyte-server: ## Tail Airbyte server logs
	kubectl logs -f deploy/airbyte-server -n $(NAMESPACE)

logs-airbyte-worker: ## Tail Airbyte worker logs
	kubectl logs -f -l airbyte=worker -n $(NAMESPACE)

airbyte-pods: ## List Airbyte pods
	kubectl get pods -n $(NAMESPACE) -l app.kubernetes.io/name=airbyte

# SQLMesh operations
build-sqlmesh: ## Build SQLMesh Docker image
	docker build -t ghcr.io/soypete/eleduck-sqlmesh:latest -f docker/sqlmesh/Dockerfile .

push-sqlmesh: ## Push SQLMesh Docker image
	docker push ghcr.io/soypete/eleduck-sqlmesh:latest

sqlmesh-plan: ## Run sqlmesh plan via Kubernetes job
	kubectl delete job sqlmesh-manual -n $(NAMESPACE) --ignore-not-found
	kubectl apply -f k8s/sqlmesh/job-manual.yaml
	kubectl wait --for=condition=complete job/sqlmesh-manual -n $(NAMESPACE) --timeout=600s
	kubectl logs job/sqlmesh-manual -n $(NAMESPACE)

sqlmesh-run: ## Run sqlmesh run via Kubernetes job
	kubectl delete job sqlmesh-manual -n $(NAMESPACE) --ignore-not-found
	sed 's/plan --auto-apply/run/' k8s/sqlmesh/job-manual.yaml | kubectl apply -f -
	kubectl wait --for=condition=complete job/sqlmesh-manual -n $(NAMESPACE) --timeout=600s

sqlmesh-audit: ## Run sqlmesh audit via Kubernetes job
	kubectl delete job sqlmesh-manual -n $(NAMESPACE) --ignore-not-found
	sed 's/plan --auto-apply/audit/' k8s/sqlmesh/job-manual.yaml | kubectl apply -f -
	kubectl wait --for=condition=complete job/sqlmesh-manual -n $(NAMESPACE) --timeout=300s

sqlmesh-logs: ## View latest SQLMesh job logs
	kubectl logs -l job-name=sqlmesh-manual -n $(NAMESPACE)

generate-dim-date: ## Generate dim_date seed CSV
	python scripts/generate_dim_date.py
