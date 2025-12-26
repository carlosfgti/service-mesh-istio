#!/usr/bin/env bash
# Script pra testar retry policy do Istio

set -euo pipefail

INGRESS_URL=${1:-http://localhost:8080}
NUM_REQUESTS=${2:-20}

echo "Testando retry policy com ${NUM_REQUESTS} requests..."
echo "URL: ${INGRESS_URL}"
echo ""

success=0
failed=0
retried=0

for i in $(seq 1 "$NUM_REQUESTS"); do
  response=$(curl -s -w "\n%{http_code}" "$INGRESS_URL/")
  http_code=$(echo "$response" | tail -n1)
  
  if [ "$http_code" = "200" ]; then
    ((success++))
    echo -n "✓"
  else
    ((failed++))
    echo -n "✗"
  fi
  
  # Verifica se houve retry (via envoy headers)
  if curl -s -v "$INGRESS_URL/" 2>&1 | grep -q "x-envoy-attempt-count"; then
    ((retried++))
  fi
  
  sleep 0.1
done

echo ""
echo ""
echo "========================================="
echo "Resultados:"
echo "  Sucesso: $success"
echo "  Falhas: $failed"
echo "  Taxa de sucesso: $(echo "scale=2; $success * 100 / $NUM_REQUESTS" | bc)%"
echo "========================================="
echo ""
echo "Para ver os retries no Jaeger:"
echo "  1. Abra http://localhost:16686"
echo "  2. Procure por 'frontend.istio-demo'"
echo "  3. Veja traces com múltiplos spans pro mesmo serviço"
