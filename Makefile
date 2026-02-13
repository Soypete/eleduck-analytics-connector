.PHONY: help build-postgres push-postgres deploy destroy psql logs-postgres port-forward-postgres \
	deploy-airbyte uninstall-airbyte port-forward-airbyte logs-airbyte-server logs-airbyte-worker airbyte-pods \
	port-forward-metabase logs-metabase restart-metabase metabase-shell

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

<<<<<<< HEAD
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
=======
# Metabase operations
port-forward-metabase: ## Port forward Metabase to localhost:3000
	@echo "Metabase available at http://localhost:3000"
	kubectl port-forward svc/metabase 3000:3000 -n $(NAMESPACE)

logs-metabase: ## Tail Metabase logs
	kubectl logs -f deploy/metabase -n $(NAMESPACE)

restart-metabase: ## Restart Metabase deployment
	kubectl rollout restart deploy/metabase -n $(NAMESPACE)

metabase-shell: ## Open shell in Metabase container
	kubectl exec -it deploy/metabase -n $(NAMESPACE) -- /bin/sh
>>>>>>> 63fda1c (feat: add Metabase deployment for analytics visualization)
