# Testando Retry Policy no Istio

Exemplos práticos de como configurar e testar retry policies no Istio.

## O que é Retry?

Retry é uma estratégia de resiliência onde o Istio automaticamente retenta requests que falharam. Isso é útil pra lidar com falhas temporárias de rede ou serviços instáveis.

## Configuração

O arquivo `k8s/retry-example.yaml` tem dois VirtualServices configurados com retry:

### Product Service
```yaml
retries:
  attempts: 3              # Tenta até 3 vezes
  perTryTimeout: 2s        # 2 segundos por tentativa
  retryOn: 5xx,reset,connect-failure,refused-stream
```

### Frontend Service  
```yaml
retries:
  attempts: 3
  perTryTimeout: 3s
  timeout: 10s             # Timeout total de 10s
  retryOn: 5xx,reset,connect-failure,refused-stream,retriable-4xx
```

## Quando o Istio faz retry?

- `5xx` - erros 500, 502, 503, 504
- `reset` - conexão resetada
- `connect-failure` - falha ao conectar
- `refused-stream` - stream recusado (HTTP/2)
- `retriable-4xx` - alguns 4xx que podem ser retentados (429, 409)

## Como testar

### 1. Aplicar o retry policy

```bash
kubectl apply -f k8s/retry-example.yaml
```

### 2. (Opcional) Deploy da versão "flaky"

Se quiser simular falhas, substitua o app product pela versão que falha aleatoriamente:

```bash
# Backup do app original
cp src/product/app.py src/product/app-stable.py

# Usar versão com falhas
cp src/product/app-flaky.py src/product/app.py

# Rebuild e redeploy
make build-images
make kind-load
kubectl -n istio-demo rollout restart deployment product
```

### 3. Rodar o teste

```bash
chmod +x scripts/test-retry.sh
./scripts/test-retry.sh
```

Você vai ver algo assim:
```
✓✗✓✓✓✗✓✓✓✓✗✓✓✓✓✓✗✓✓✓
=========================================
Resultados:
  Sucesso: 17
  Falhas: 3
  Taxa de sucesso: 85%
=========================================
```

### 4. Ver os retries no Jaeger

1. Abra http://localhost:16686
2. Procure pelo service `frontend.istio-demo`
3. Clique num trace
4. Você vai ver múltiplos spans pro mesmo serviço quando houve retry

### 5. Ver métricas no Prometheus

```promql
# Total de retries
sum(rate(envoy_cluster_upstream_rq_retry[1m]))

# Taxa de retry por serviço
rate(envoy_cluster_upstream_rq_retry{cluster_name=~".*product.*"}[1m])
```

## Ajustando a taxa de falha

Você pode controlar quantas vezes o service vai falhar:

```bash
# 50% de falhas
kubectl -n istio-demo set env deployment/product FAILURE_RATE=0.5

# 10% de falhas
kubectl -n istio-demo set env deployment/product FAILURE_RATE=0.1

# Sem falhas
kubectl -n istio-demo set env deployment/product FAILURE_RATE=0
```

## Voltar pro app estável

```bash
cp src/product/app-stable.py src/product/app.py
make build-images
make kind-load
kubectl -n istio-demo rollout restart deployment product
```

## Boas práticas

- **Não abuse dos retries**: cada retry consome recursos
- **Use timeouts**: sempre configure `perTryTimeout` e `timeout`
- **Cuidado com operações não-idempotentes**: retry em POST pode criar duplicatas
- **Monitore**: acompanhe a taxa de retry no Prometheus

## Outras políticas de resiliência

Além de retry, o Istio também suporta:
- **Circuit Breaker**: para quando um serviço tá muito lento/falhando
- **Timeout**: limita quanto tempo espera por uma resposta
- **Rate Limiting**: controla quantos requests por segundo

Quer exemplos desses? Só me avisar! 😉
