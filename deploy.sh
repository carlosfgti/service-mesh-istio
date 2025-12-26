#!/usr/bin/env bash
set -euo pipefail

echo "Applying Kubernetes manifests to namespace istio-demo"
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/product-service.yaml
kubectl apply -f k8s/product-deployment.yaml
kubectl apply -f k8s/frontend-service.yaml
kubectl apply -f k8s/frontend-deployment.yaml
kubectl apply -f k8s/istio-gateway.yaml
kubectl apply -f k8s/telemetry.yaml

echo "Resources applied. Check pods: kubectl -n istio-demo get pods"
