#!/usr/bin/env bash
# Script to install observability stack (Grafana, Prometheus, Jaeger) via Helm
# This complements the Istio installation with proper observability tools

set -euo pipefail

check_helm() {
  if ! command -v helm >/dev/null 2>&1; then
    echo "Error: helm is not installed. Please install Helm: https://helm.sh/docs/intro/install/"
    exit 1
  fi
}

add_helm_repos() {
  echo "Adding Helm repositories..."
  helm repo add grafana https://grafana.github.io/helm-charts 2>/dev/null || true
  helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>/dev/null || true
  helm repo add jaegertracing https://jaegertracing.github.io/helm-charts 2>/dev/null || true
  helm repo update
  echo "Helm repos updated."
}

install_prometheus_stack() {
  echo "Installing kube-prometheus-stack (includes Grafana)..."
  helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
    --namespace istio-system \
    --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
    --wait --timeout 5m
  echo "✓ Prometheus and Grafana installed"
}

install_jaeger() {
  echo "Installing Jaeger (all-in-one with in-memory storage)..."
  helm upgrade --install jaeger jaegertracing/jaeger \
    --namespace istio-system \
    --set provisionDataStore.cassandra=false \
    --set allInOne.enabled=true \
    --set storage.type=memory \
    --set agent.enabled=false \
    --set collector.enabled=false \
    --set query.enabled=false \
    --wait --timeout 5m
  echo "✓ Jaeger installed"
}

get_grafana_password() {
  echo ""
  echo "Grafana admin password:"
  kubectl --namespace istio-system get secrets prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 -d
  echo ""
}

main() {
  check_helm
  add_helm_repos
  install_prometheus_stack
  install_jaeger
  
  echo ""
  echo "========================================="
  echo "Observability stack installed!"
  echo "========================================="
  echo ""
  echo "Services available in istio-system namespace:"
  kubectl -n istio-system get svc | grep -E "(grafana|prometheus|jaeger|NAME)"
  echo ""
  
  get_grafana_password
  
  echo ""
  echo "To access dashboards, run: ./scripts/port-forward-dashboards.sh"
  echo "Or use setup-observability.sh for automatic setup including port-forwards."
}

main "$@"
