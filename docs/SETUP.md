# Resumo das Configurações

Este documento lista todas as configurações aplicadas no projeto de demonstração do Istio.

## Estrutura do Projeto

```
service-mesh-istio/
├── k8s/                          # Manifestos Kubernetes
│   ├── namespace.yaml            # Namespace istio-demo com label de injection
│   ├── product-deployment.yaml   # Deployment do serviço product
│   ├── product-service.yaml      # Service para product
│   ├── frontend-deployment.yaml  # Deployment do serviço frontend
│   ├── frontend-service.yaml     # Service para frontend
│   ├── istio-gateway.yaml        # Gateway e VirtualService do Istio
│   └── telemetry.yaml            # Configuração de tracing (100% sampling)
├── src/
│   ├── frontend/                 # App Flask frontend (chama product)
│   │   ├── app.py
│   │   ├── requirements.txt
│   │   └── Dockerfile
│   └── product/                  # App Flask product (retorna produtos)
│       ├── app.py
│       ├── requirements.txt
│       └── Dockerfile
├── scripts/
│   ├── create-kind.sh            # Cria cluster kind com port mappings
│   ├── install-istio.sh          # Instala Istio com tracing habilitado
│   ├── deploy.sh                 # Aplica todos os manifestos k8s
│   ├── install-observability.sh # Instala Grafana/Prometheus/Jaeger via Helm
│   ├── setup-observability.sh   # Setup completo automático
│   ├── port-forward-dashboards.sh # Port-forwards para dashboards
│   └── generate-traffic.sh      # Gera tráfego de teste
├── docs/
│   ├── QUICKSTART.md             # Guia rápido de setup
│   ├── SETUP.md                  # Documentação técnica
│   └── scripts.md                # Documentação dos scripts
├── kind-config.yaml              # Configuração do cluster kind
├── Makefile                      # Targets úteis para automação
└── README.md                     # Documentação principal

```

## Configurações Aplicadas

### 1. Istio
- **Perfil**: demo
- **Tracing habilitado**: 100% sampling
- **Backend de tracing**: Zipkin protocol → Jaeger (porta 9411)
- **Endpoint**: jaeger.istio-system.svc.cluster.local:9411

Comando usado:
```bash
istioctl install --set profile=demo \
  --set meshConfig.enableTracing=true \
  --set meshConfig.defaultConfig.tracing.zipkin.address=jaeger.istio-system.svc.cluster.local:9411 \
  --set meshConfig.defaultConfig.tracing.sampling=100 \
  -y
```

### 2. Observabilidade (via Helm)

#### Prometheus + Grafana (kube-prometheus-stack)
```bash
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace istio-system \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false
```

**Serviços criados:**
- `prometheus-grafana` (porta 80)
- `prometheus-kube-prometheus-prometheus` (porta 9090)
- `prometheus-kube-prometheus-operator`
- `prometheus-kube-state-metrics`
- `alertmanager`

#### Jaeger
```bash
helm install jaeger jaegertracing/jaeger \
  --namespace istio-system \
  --set provisionDataStore.cassandra=false \
  --set allInOne.enabled=true \
  --set storage.type=memory
```

**Serviço criado:**
- `jaeger` (portas: 9411 zipkin, 16686 query UI)

### 3. Telemetry Resource
Arquivo: `k8s/telemetry.yaml`

Configura o provider de tracing `jaeger` com 100% de sampling em todo o mesh.

### 4. Aplicações

#### Frontend
- Imagem: `frontend:demo`
- Porta: 5000
- Variável de ambiente: `PRODUCT_URL=http://product:5000/products`
- Endpoint: `GET /` → chama product e retorna JSON

#### Product
- Imagem: `product:demo`
- Porta: 5000
- Endpoints:
  - `GET /` → status
  - `GET /products` → lista de produtos

Ambas as apps têm sidecars Envoy injetados automaticamente (namespace com label `istio-injection=enabled`).

### 5. Kind Cluster
Arquivo: `kind-config.yaml`

Port mappings:
- 8080 (host) → 80 (ingress gateway)
- 30000 (host) → 3000 (grafana)
- 30900 (host) → 9090 (prometheus)

### 6. Port-forwards Ativos

Para acessar os serviços localmente:
```bash
kubectl -n istio-system port-forward svc/prometheus-grafana 3000:80
kubectl -n istio-system port-forward svc/prometheus-kube-prometheus-prometheus 9090:9090
kubectl -n istio-system port-forward svc/jaeger 16686:16686
kubectl -n istio-system port-forward svc/istio-ingressgateway 8080:80
```

Ou use: `make port-forward`

## Acessos

- **Frontend**: http://localhost:8080
- **Grafana**: http://localhost:3000 (admin / ver senha com `kubectl get secret`)
- **Prometheus**: http://localhost:9090
- **Jaeger**: http://localhost:16686

## Comandos Úteis

```bash
# Status geral
make status

# Gerar tráfego
make generate-traffic

# Reiniciar apps (pegar nova config)
make restart-apps

# Logs
kubectl -n istio-demo logs -f deployment/frontend
kubectl -n istio-demo logs -f deployment/product

# Verificar envoy config
kubectl -n istio-demo exec deployment/frontend -c istio-proxy -- pilot-agent request GET config_dump

# Ver traces sendo enviados
kubectl -n istio-demo exec deployment/frontend -c istio-proxy -- pilot-agent request GET clusters | grep zipkin
```

## Dashboards Úteis no Grafana

IDs para importar:
- **7636**: Istio Mesh Dashboard
- **7639**: Istio Service Dashboard  
- **7645**: Istio Workload Dashboard

## Queries Prometheus

```promql
# Taxa de requisições total
rate(istio_requests_total[1m])

# Taxa de requisições por destination
rate(istio_requests_total{destination_service_name="product"}[1m])

# Latência p95
histogram_quantile(0.95, rate(istio_request_duration_milliseconds_bucket[5m]))

# Requisições com erro
sum(rate(istio_requests_total{response_code=~"5.."}[1m]))
```

## Troubleshooting

### Traces não aparecem no Jaeger
1. Verificar se Telemetry está aplicado: `kubectl get telemetry -A`
2. Verificar config do envoy: `kubectl -n istio-demo exec deployment/frontend -c istio-proxy -- pilot-agent request GET config_dump | grep tracing`
3. Verificar se requisições estão sendo enviadas: `kubectl -n istio-demo exec deployment/frontend -c istio-proxy -- pilot-agent request GET clusters | grep zipkin`
4. Gerar tráfego novo após configuração: `make generate-traffic`

### Pods não iniciam (ImagePullBackOff)
```bash
make build-images
make kind-load
kubectl -n istio-demo rollout restart deployment frontend product
```

### Port-forward não funciona
```bash
# Parar todos
pkill -f "kubectl.*port-forward"
# Reiniciar
make port-forward
```
