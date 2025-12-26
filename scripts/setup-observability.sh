#!/usr/bin/env bash
set -euo pipefail

NAMESPACE=istio-system
PORT_FORWARD_PIDS_FILE=/tmp/istio-observability-pids.txt

check_cmd(){
  command -v "$1" >/dev/null 2>&1 || { echo "Required command '$1' not found. Please install it." >&2; exit 1; }
}

check_cmd kubectl
check_cmd istioctl || echo "istioctl not found; will try Helm-only installation for addons"

echo "Ensure namespace ${NAMESPACE} exists"
kubectl get ns ${NAMESPACE} >/dev/null 2>&1 || kubectl create namespace ${NAMESPACE}

install_istio_if_missing(){
  if ! istioctl version --remote=false >/dev/null 2>&1; then
    echo "Istio control plane not detected locally. Installing Istio (demo profile)..."
    istioctl install --set profile=demo -y
  else
    echo "Istio appears installed. Skipping istioctl install."
  fi
}

wait_for_deployment(){
  local ns=$1 name=$2 timeout=${3:-300}
  echo "Waiting for deployment ${name} in ${ns} to be ready (timeout ${timeout}s)..."
  kubectl -n ${ns} wait --for=condition=available deployment/${name} --timeout=${timeout}s
}

install_addons_via_helm(){
  if ! command -v helm >/dev/null 2>&1; then
    echo "Helm not found; cannot install addons via Helm. Please install Helm or run 'istioctl install --set profile=demo -y' manually." >&2
    return 1
  fi

  echo "Adding Helm repos for Grafana/Prometheus/Jaeger..."
  helm repo add grafana https://grafana.github.io/helm-charts >/dev/null 2>&1 || true
  helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null 2>&1 || true
  helm repo add jaegertracing https://jaegertracing.github.io/helm-charts >/dev/null 2>&1 || true
  helm repo update >/dev/null 2>&1 || true

  # Prometheus
  if ! kubectl -n ${NAMESPACE} get deployment prometheus >/dev/null 2>&1; then
    echo "Installing Prometheus via Helm..."
    helm upgrade --install prometheus prometheus-community/prometheus --namespace ${NAMESPACE} --wait --timeout 10m
  else
    echo "Prometheus deployment found; skipping Helm install."
  fi

  # Grafana
  if ! kubectl -n ${NAMESPACE} get deployment grafana >/dev/null 2>&1; then
    echo "Installing Grafana via Helm..."
    helm upgrade --install grafana grafana/grafana --namespace ${NAMESPACE} --set service.type=ClusterIP --wait --timeout 10m
  else
    echo "Grafana deployment found; skipping Helm install."
  fi

  # Jaeger
  if ! kubectl -n ${NAMESPACE} get deployment jaeger >/dev/null 2>&1; then
    echo "Installing Jaeger via Helm..."
    helm upgrade --install jaeger jaegertracing/jaeger --namespace ${NAMESPACE} --wait --timeout 10m
  else
    echo "Jaeger deployment found; skipping Helm install."
  fi
}

port_forward(){
  local ns=$1 svc=$2 local_port=$3 remote_port=$4
  echo "Port-forwarding ${svc} ${local_port}:${remote_port} (namespace ${ns})"
  kubectl -n ${ns} port-forward svc/${svc} ${local_port}:${remote_port} >/dev/null 2>&1 &
  echo $! >> ${PORT_FORWARD_PIDS_FILE}
}

cleanup_port_forwards(){
  if [[ -f ${PORT_FORWARD_PIDS_FILE} ]]; then
    echo "Killing port-forward PIDs from ${PORT_FORWARD_PIDS_FILE}"
    xargs -a ${PORT_FORWARD_PIDS_FILE} -r kill || true
    rm -f ${PORT_FORWARD_PIDS_FILE}
  else
    echo "No port-forward PID file found."
  fi
}

main(){
  echo "Starting observability setup..."

  # Install Istio if needed
  if command -v istioctl >/dev/null 2>&1; then
    install_istio_if_missing
  else
    echo "istioctl not available — skipping istioctl install step. Will attempt to install addons via Helm if Helm is present."
  fi

  echo "Ensuring Istio core deployments are ready (istiod, ingressgateway)..."
  wait_for_deployment ${NAMESPACE} istiod 300 || true
  wait_for_deployment ${NAMESPACE} istio-ingressgateway 300 || true

  # Install addons if missing
  if ! kubectl -n ${NAMESPACE} get deployment grafana prometheus jaeger --ignore-not-found >/dev/null 2>&1; then
    echo "Grafana/Prometheus/Jaeger not all present — attempting Helm install of addons"
    if ! install_addons_via_helm; then
      echo "Helm installation failed or Helm missing. You may need to install addons manually." >&2
    fi
  else
    echo "Some addons already present; skipping Helm installs."
  fi

  # Wait for addons
  echo "Waiting for Grafana, Prometheus, Jaeger deployments..."
  kubectl -n ${NAMESPACE} get deploy grafana prometheus jaeger --ignore-not-found || true
  wait_for_deployment ${NAMESPACE} grafana 300 || true
  wait_for_deployment ${NAMESPACE} prometheus 300 || true
  wait_for_deployment ${NAMESPACE} jaeger 300 || true

  # Cleanup previous port-forwards
  cleanup_port_forwards || true

  # Start port-forwards
  port_forward ${NAMESPACE} grafana 3000 80 || true
  port_forward ${NAMESPACE} prometheus 30900 9090 || true
  port_forward ${NAMESPACE} jaeger-query 16686 16686 || true

  # Ensure ingressgateway reachable — prefer existing external IP, else port-forward
  GATEWAY_IP=$(kubectl -n ${NAMESPACE} get svc istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)
  if [[ -z "$GATEWAY_IP" ]]; then
    echo "No external IP for istio-ingressgateway found — starting port-forward to localhost:8080"
    kubectl -n ${NAMESPACE} port-forward svc/istio-ingressgateway 8080:80 >/dev/null 2>&1 &
    echo $! >> ${PORT_FORWARD_PIDS_FILE}
    GATEWAY_HOST="http://localhost:8080"
  else
    GATEWAY_HOST="http://${GATEWAY_IP}"
  fi

  echo "Dashboards available (local):"
  echo "Grafana: http://localhost:3000"
  echo "Prometheus: http://localhost:30900"
  echo "Jaeger: http://localhost:16686"

  echo "Generating sample traffic to frontend via ingress to create traces/metrics..."
  for i in {1..30}; do
    curl -s ${GATEWAY_HOST}/ >/dev/null || true
    sleep 0.2
  done

  echo "Setup complete. Port-forwards running in background; PIDs stored in ${PORT_FORWARD_PIDS_FILE}"
  echo "To stop port-forwards: ${0} --stop"
}

if [[ ${1:-} == "--stop" ]]; then
  cleanup_port_forwards
  exit 0
fi

main "$@"
