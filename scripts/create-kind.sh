#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME=${1:-kind-istio}
KIND_CONFIG="$(dirname "$0")/../kind-config.yaml"

echo "Creating kind cluster '${CLUSTER_NAME}' using ${KIND_CONFIG}..."
kind create cluster --name "${CLUSTER_NAME}" --config "${KIND_CONFIG}"

echo "Setting kubectl context to kind-${CLUSTER_NAME}"
kubectl cluster-info --context kind-${CLUSTER_NAME}

echo "If you built local images, load them into kind (frontend:demo product:demo)"
kind load docker-image frontend:demo --name "${CLUSTER_NAME}" || true
kind load docker-image product:demo --name "${CLUSTER_NAME}" || true

echo "Cluster '${CLUSTER_NAME}' created. Istio ingress will be reachable on http://localhost:8080"
echo "Grafana (if installed) reachable on http://localhost:30000 and Prometheus on http://localhost:30900"
