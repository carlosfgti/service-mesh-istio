# Circuit Breaker no Istio

O Circuit Breaker é um padrão de resiliência que previne cascatas de falhas. Quando um serviço está falhando ou lento, o circuit breaker "abre" e rejeita requisições rapidamente ao invés de esperar por timeouts.

## Como funciona

1. **Fechado (Closed)**: Requisições passam normalmente
2. **Aberto (Open)**: Após X falhas, o circuit breaker abre e rejeita requisições
3. **Semi-aberto (Half-Open)**: Após um tempo, permite algumas requisições de teste

## Configuração

### DestinationRule com Circuit Breaker

```yaml
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: product-circuit-breaker
  namespace: istio-demo
spec:
  host: product
  trafficPolicy:
    connectionPool:
      tcp:
        maxConnections: 1          # Máximo de conexões TCP
      http:
        http1MaxPendingRequests: 1 # Fila de requisições
        maxRequestsPerConnection: 1
    outlierDetection:
      consecutive5xxErrors: 1      # Erros para abrir o circuit breaker
      interval: 1s                 # Intervalo de análise
      baseEjectionTime: 3s         # Tempo que fica aberto
      maxEjectionPercent: 100      # % de pods que podem ser ejetados
      minHealthPercent: 0
```

### Parâmetros importantes

**connectionPool:**
- `maxConnections`: Limite de conexões TCP simultâneas
- `http1MaxPendingRequests`: Fila de espera (acima disso = 503)
- `maxRequestsPerConnection`: Requisições por conexão HTTP/1.1

**outlierDetection:**
- `consecutive5xxErrors`: Quantos erros 5xx seguidos para ejetar o pod
- `interval`: Janela de tempo para análise
- `baseEjectionTime`: Quanto tempo o pod fica ejetado
- `maxEjectionPercent`: Limite de pods ejetados simultaneamente

## Setup do Teste

### 1. Build e Deploy do slow-service

```bash
# Build da imagem
docker build -t slow-service:demo ./src/slow-service

# Carrega no kind
kind load docker-image slow-service:demo --name kind-istio

# Deploy
kubectl apply -f k8s/slow-service/

# Aplica circuit breaker
kubectl apply -f k8s/circuit-breaker-example.yaml
```

### 2. Adicionar rota no Gateway

Edite `k8s/istio-gateway.yaml` e adicione:

```yaml
- match:
  - uri:
      prefix: /slow
  route:
  - destination:
      host: slow-service
      port:
        number: 5000
```

Aplique: `kubectl apply -f k8s/istio-gateway.yaml`

### 3. Executar teste

```bash
chmod +x scripts/test-circuit-breaker.sh
./scripts/test-circuit-breaker.sh
```

## O que observar

### Comportamento esperado:

1. **Sem circuit breaker**: 
   - Requisições demoram 5s (timeout)
   - Todos esperam a resposta
   - Cascata de falhas

2. **Com circuit breaker**:
   - Primeiras requisições lentas
   - Circuit breaker detecta problemas
   - Próximas requisições retornam 503 imediatamente
   - Não espera timeout
   - Após `baseEjectionTime`, tenta novamente

### Métricas do Envoy

```bash
# Ver estatísticas do circuit breaker
kubectl -n istio-demo exec deployment/frontend -c istio-proxy -- \
  curl localhost:15000/stats | grep circuit_breakers
```

Métricas importantes:
- `circuit_breakers.default.rq_pending_open`: Circuit breaker aberto
- `circuit_breakers.default.rq_open`: Requisições rejeitadas
- `upstream_rq_pending_overflow`: Fila cheia (503)

## Testando diferentes cenários

### Cenário 1: Serviço lento

```bash
# Aumenta a lentidão
kubectl -n istio-demo set env deployment/slow-service SLOW_RATE=0.8 SLOW_DURATION=10

# Testa
./scripts/test-circuit-breaker.sh
```

### Cenário 2: Muitos erros

```bash
# Aumenta taxa de erro
kubectl -n istio-demo set env deployment/slow-service ERROR_RATE=0.5

# Testa
./scripts/test-circuit-breaker.sh
```

### Cenário 3: Circuit breaker mais agressivo

Edite `circuit-breaker-example.yaml`:

```yaml
outlierDetection:
  consecutive5xxErrors: 1    # Abre após 1 erro
  interval: 1s
  baseEjectionTime: 10s      # Fica aberto por 10s
```

## Boas práticas

1. **Balance connectionPool com carga**: Não deixe muito restritivo
2. **baseEjectionTime apropriado**: Tempo suficiente para o serviço se recuperar
3. **maxEjectionPercent < 100**: Mantenha alguns pods ativos
4. **Combine com retry**: Retry tenta, circuit breaker protege
5. **Monitore**: Use Grafana/Kiali para ajustar valores

## Troubleshooting

### Circuit breaker não ativa

- Verifique se `consecutive5xxErrors` não está muito alto
- Confirme que o serviço está retornando 5xx
- Veja logs: `kubectl logs -n istio-demo deployment/slow-service`

### Muitos 503s legítimos

- Aumente `http1MaxPendingRequests`
- Aumente `maxConnections`
- Considere escalar o serviço

### Pods sendo ejetados permanentemente

- Aumente `baseEjectionTime`
- Verifique saúde real dos pods
- Ajuste `consecutive5xxErrors` para ser menos sensível

## Visualização

### Grafana
```bash
# Port-forward se necessário
kubectl -n istio-system port-forward svc/prometheus-grafana 3000:80

# Acesse http://localhost:3000
# Dashboards > Istio Service Dashboard
```

### Kiali (opcional)
```bash
# Instala Kiali
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/kiali.yaml

# Port-forward
kubectl -n istio-system port-forward svc/kiali 20001:20001

# Acesse http://localhost:20001
```

## Diferença entre Retry e Circuit Breaker

| Aspecto | Retry | Circuit Breaker |
|---------|-------|-----------------|
| Objetivo | Recuperar de falhas transitórias | Prevenir cascata de falhas |
| Ação | Tenta novamente | Rejeita rapidamente |
| Quando usar | Falhas ocasionais | Serviço degradado/sobrecarregado |
| Latência | Pode aumentar (tenta várias vezes) | Reduz (fail fast) |
| Combinação | Use ambos! | Retry para falhas pontuais, CB para proteção |

## Próximos passos

1. ✅ Teste o circuit breaker com carga
2. 📊 Monitore as métricas no Grafana
3. 🔧 Ajuste os valores baseado no comportamento
4. 🎯 Combine com rate limiting para proteção completa
