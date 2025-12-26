#!/usr/bin/env bash
set -euo pipefail

PORT_FORWARD_PIDS_FILE=/tmp/istio-observability-pids.txt

cleanup() {
  if [[ -f ${PORT_FORWARD_PIDS_FILE} ]]; then
    echo "Stopping port-forwards..."
    while read -r pid; do
      kill "$pid" 2>/dev/null || true
    done < "${PORT_FORWARD_PIDS_FILE}"
    rm -f "${PORT_FORWARD_PIDS_FILE}"
    echo "Port-forwards stopped."
  fi
}

if [[ ${1:-} == "--stop" ]]; then
  cleanup
  exit 0
fi

# Clean up any existing port-forwards
cleanup

echo "Starting port-forwards for dashboards..."

# Grafana
kubectl -n istio-system port-forward svc/prometheus-grafana 3000:80 >/dev/null 2>&1 &
echo $! >> "${PORT_FORWARD_PIDS_FILE}"
echo "- Grafana: http://localhost:3000"

# Prometheus
kubectl -n istio-system port-forward svc/prometheus-kube-prometheus-prometheus 9090:9090 >/dev/null 2>&1 &
echo $! >> "${PORT_FORWARD_PIDS_FILE}"
echo "- Prometheus: http://localhost:9090"

# Jaeger
kubectl -n istio-system port-forward svc/jaeger 16686:16686 >/dev/null 2>&1 &
echo $! >> "${PORT_FORWARD_PIDS_FILE}"
echo "- Jaeger: http://localhost:16686"

# Istio Ingress Gateway
kubectl -n istio-system port-forward svc/istio-ingressgateway 8080:80 >/dev/null 2>&1 &
echo $! >> "${PORT_FORWARD_PIDS_FILE}"
echo "- Frontend (via Ingress): http://localhost:8080"

echo ""
echo "All port-forwards running in background."
echo "PIDs stored in: ${PORT_FORWARD_PIDS_FILE}"
echo ""
echo "To stop: $0 --stop"
echo ""
echo "Grafana credentials:"
echo "  User: admin"
echo "  Password: (run) kubectl -n istio-system get secrets prometheus-grafana -o jsonpath='{.data.admin-password}' | base64 -d"
