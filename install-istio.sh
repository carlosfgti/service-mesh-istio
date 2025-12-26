#!/usr/bin/env bash
set -euo pipefail

if ! command -v istioctl >/dev/null 2>&1; then
  echo "istioctl not found. Please install istioctl: https://istio.io/latest/docs/setup/getting-started/#download"
  exit 1
fi

echo "Installing Istio (demo profile) with tracing enabled..."
istioctl install --set profile=demo \
  --set meshConfig.enableTracing=true \
  --set meshConfig.defaultConfig.tracing.zipkin.address=jaeger.istio-system.svc.cluster.local:9411 \
  --set meshConfig.defaultConfig.tracing.sampling=100 \
  -y

echo "Istio installed with tracing configured."

echo "Create and label demo namespace for automatic sidecar injection:"
kubectl create namespace istio-demo --dry-run=client -o yaml | kubectl apply -f -
kubectl label namespace istio-demo istio-injection=enabled --overwrite

echo "Done. Note: For observability, run scripts/setup-observability.sh to install Grafana/Prometheus/Jaeger."
