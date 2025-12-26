#!/bin/bash

echo "==================================="
echo "Circuit Breaker Load Test"
echo "==================================="
echo ""

# Cores para output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configurações
URL="http://localhost:8080/slow"
CONCURRENT_REQUESTS=20
TOTAL_REQUESTS=100

echo "Configuração:"
echo "  URL: $URL"
echo "  Requisições concorrentes: $CONCURRENT_REQUESTS"
echo "  Total de requisições: $TOTAL_REQUESTS"
echo ""

# Verifica se o port-forward está rodando
if ! curl -s http://localhost:8080 > /dev/null 2>&1; then
    echo -e "${RED}❌ Port-forward não está rodando!${NC}"
    echo "Execute: kubectl -n istio-system port-forward svc/istio-ingressgateway 8080:80"
    exit 1
fi

echo "Gerando carga..."
echo ""

# Processa resultados
success=0
failed=0
circuit_breaker_triggered=0
timeout=0

# Faz requests concorrentes e processa resultados
for i in $(seq 1 $TOTAL_REQUESTS); do
    # Executa em background
    (
        response=$(curl -s -w "\n%{http_code}" -o /dev/null "$URL/api/data" 2>&1)
        status_code=$(echo "$response" | tail -n 1)
        echo "$status_code"
    ) &
    
    # A cada batch de requests, espera e mostra progresso
    if [ $((i % CONCURRENT_REQUESTS)) -eq 0 ]; then
        wait
        printf "."
    fi
done > /tmp/circuit-breaker-results.txt

wait
echo ""
echo ""

# Lê resultados do arquivo temporário
while read -r status; do
    case $status in
        200)
            ((success++))
            ;;
        503)
            ((circuit_breaker_triggered++))
            ;;
        000|"")
            ((timeout++))
            ;;
        *)
            ((failed++))
            ;;
    esac
done < /tmp/circuit-breaker-results.txt

rm -f /tmp/circuit-breaker-results.txt

total=$((success + failed + circuit_breaker_triggered + timeout))

# Exibe resultados
echo "========================================="
echo "Resultados:"
echo "========================================="
echo -e "${GREEN}✓ Sucesso (200):${NC} $success"
echo -e "${YELLOW}⚠ Circuit Breaker (503):${NC} $circuit_breaker_triggered"
echo -e "${RED}✗ Timeout:${NC} $timeout"
echo -e "${RED}✗ Outros erros:${NC} $failed"
echo "========================================="
echo "Total processado: $total"

if [ $circuit_breaker_triggered -gt 0 ]; then
    percentage=$(awk "BEGIN {printf \"%.2f\", ($circuit_breaker_triggered / $total) * 100}")
    echo -e "${YELLOW}Circuit breaker ativado em ${percentage}% das requisições${NC}"
fi

echo ""
echo "Para visualizar no Grafana:"
echo "  1. Abra http://localhost:3000"
echo "  2. Vá em Dashboards > Istio"
echo "  3. Procure por métricas de circuit breaker"
echo ""
echo "Para visualizar no Kiali:"
echo "  kubectl -n istio-system port-forward svc/kiali 20001:20001"
echo "  Abra http://localhost:20001"
echo ""
