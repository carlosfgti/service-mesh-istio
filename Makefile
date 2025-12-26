IMAGE_FRONTEND=frontend:demo
IMAGE_PRODUCT=product:demo
CLUSTER_NAME=kind-istio

.PHONY: build-images deploy apply clean install-istio install-observability port-forward generate-traffic restart-apps status help

help:
	@echo "Available targets:"
	@echo "  make build-images          - Build Docker images for frontend and product"
	@echo "  make create-kind           - Create kind cluster with istio config"
	@echo "  make kind-load             - Load images into kind cluster"
	@echo "  make install-istio         - Install Istio with tracing enabled"
	@echo "  make install-observability - Install Grafana/Prometheus/Jaeger via Helm"
	@echo "  make deploy                - Build images and deploy to cluster"
	@echo "  make apply                 - Apply all k8s manifests"
	@echo "  make port-forward          - Start port-forwards for dashboards"
	@echo "  make generate-traffic      - Generate test traffic (50 requests)"
	@echo "  make restart-apps          - Restart frontend and product deployments"
	@echo "  make status                - Show status of all resources"
	@echo "  make clean                 - Delete all k8s resources"

build-images:
	docker build -t $(IMAGE_FRONTEND) ./src/frontend
	docker build -t $(IMAGE_PRODUCT) ./src/product

create-kind:
	@bash scripts/create-kind.sh $(CLUSTER_NAME)

kind-load:
	@kind load docker-image $(IMAGE_FRONTEND) --name $(CLUSTER_NAME) || true
	@kind load docker-image $(IMAGE_PRODUCT) --name $(CLUSTER_NAME) || true

install-istio:
	@chmod +x install-istio.sh
	@./install-istio.sh

install-observability:
	@chmod +x scripts/install-observability.sh
	@bash scripts/install-observability.sh

deploy: build-images kind-load
	@chmod +x deploy.sh
	@./deploy.sh

apply:
	kubectl apply -f k8s/

port-forward:
	@chmod +x scripts/port-forward-dashboards.sh
	@bash scripts/port-forward-dashboards.sh

generate-traffic:
	@chmod +x scripts/generate-traffic.sh
	@bash scripts/generate-traffic.sh http://localhost:8080 50

restart-apps:
	kubectl -n istio-demo rollout restart deployment frontend product

status:
	@echo "=== Istio System ==="
	@kubectl -n istio-system get pods
	@echo ""
	@echo "=== Demo Apps ==="
	@kubectl -n istio-demo get pods,svc
	@echo ""
	@echo "=== Observability ==="
	@kubectl -n istio-system get svc | grep -E "(grafana|prometheus|jaeger|NAME)" || true

clean:
	kubectl delete -f k8s/ --ignore-not-found
