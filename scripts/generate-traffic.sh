#!/usr/bin/env bash
# Generate test traffic to populate metrics and traces

set -euo pipefail

INGRESS_URL=${1:-http://localhost:8080}
NUM_REQUESTS=${2:-50}

echo "Generating ${NUM_REQUESTS} requests to ${INGRESS_URL}..."

success=0
failed=0

for i in $(seq 1 "$NUM_REQUESTS"); do
  if curl -s -o /dev/null -w "%{http_code}" "$INGRESS_URL/" | grep -q "200"; then
    ((success++))
    echo -n "."
  else
    ((failed++))
    echo -n "x"
  fi
  sleep 0.2
done

echo ""
echo "Traffic generation complete!"
echo "Success: $success | Failed: $failed"
echo ""
echo "View traces in Jaeger: http://localhost:16686"
echo "View metrics in Grafana: http://localhost:3000"
echo "View metrics in Prometheus: http://localhost:9090"
