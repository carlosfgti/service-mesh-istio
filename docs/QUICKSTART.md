# Guia Rápido - Setup do Zero

Este guia mostra como configurar o ambiente completo do zero.

## Pré-requisitos

- Docker Desktop rodando
- `kubectl` instalado
- `kind` instalado
- `istioctl` instalado  
- `helm` instalado

## Setup Completo (Passo a Passo)

### 1. Criar cluster Kind
```bash
make create-kind
# ou
bash scripts/create-kind.sh kind-istio
```

Aguarde o cluster estar pronto (~30 segundos).

### 2. Instalar Istio com tracing
```bash
make install-istio
# ou
./scripts/install-istio.sh
```

Isso instala:
- Istiod (control plane)
- Istio Ingress Gateway
- Istio Egress Gateway
- Configuração de tracing para Jaeger

### 3. Build e carregar imagens
```bash
make build-images
make kind-load
```

### 4. Deploy das aplicações
```bash
make apply
# ou
./scripts/deploy.sh
```

Aguarde os pods ficarem prontos:
```bash
kubectl -n istio-demo get pods -w
# Espere até ver 2/2 em READY
```

### 5. Instalar observabilidade
```bash
make install-observability
# ou
bash scripts/install-observability.sh
```

Isso instala via Helm:
- Prometheus
- Grafana
- Jaeger

Aguarde os pods de observabilidade ficarem prontos (~2-3 minutos):
```bash
kubectl -n istio-system get pods -w
```

### 6. Iniciar port-forwards
```bash
make port-forward
# ou
bash scripts/port-forward-dashboards.sh
```

### 7. Gerar tráfego de teste
```bash
make generate-traffic
# ou
bash scripts/generate-traffic.sh
```

### 8. Acessar dashboards

- **Frontend**: http://localhost:8080
  ```bash
  curl http://localhost:8080/
  ```

- **Grafana**: http://localhost:3000
  - User: `admin`
  - Senha:
    ```bash
    kubectl -n istio-system get secrets prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 -d
    ```

- **Prometheus**: http://localhost:9090

- **Jaeger**: http://localhost:16686
  - Procure por service: `frontend.istio-demo` ou `product.istio-demo`

## Comandos em Sequência (Copy/Paste)

```bash
# 1. Setup cluster e Istio
make create-kind
make install-istio

# 2. Build e deploy apps
make build-images
make kind-load
make apply

# 3. Aguarde apps estarem prontas
kubectl -n istio-demo wait --for=condition=ready pod --all --timeout=120s

# 4. Setup observabilidade
make install-observability

# 5. Aguarde observabilidade estar pronta
kubectl -n istio-system wait --for=condition=ready pod -l app.kubernetes.io/name=grafana --timeout=300s

# 6. Port-forwards e tráfego
make port-forward
sleep 5
make generate-traffic

# 7. Obter senha do Grafana
kubectl -n istio-system get secrets prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 -d && echo

# 8. Abrir dashboards
open http://localhost:3000  # Grafana
open http://localhost:9090  # Prometheus
open http://localhost:16686 # Jaeger
open http://localhost:8080  # Frontend
```

## Método Alternativo (Setup Automático)

Se preferir um setup totalmente automatizado:

```bash
# 1. Criar cluster
make create-kind

# 2. Build e carregar imagens
make build-images
make kind-load

# 3. Executar setup-observability.sh (faz tudo)
chmod +x scripts/setup-observability.sh
./scripts/setup-observability.sh
```

O script `setup-observability.sh`:
- Instala Istio se necessário
- Instala addons via Helm
- Configura port-forwards
- Gera tráfego de teste

## Verificação do Setup

```bash
# Status geral
make status

# Verificar se tudo está rodando
kubectl -n istio-system get pods
kubectl -n istio-demo get pods

# Testar frontend
curl http://localhost:8080/

# Ver traces no Jaeger
# Abra http://localhost:16686 e procure por "frontend.istio-demo"
```

## Limpeza

```bash
# Parar port-forwards
bash scripts/port-forward-dashboards.sh --stop

# Deletar recursos k8s
make clean

# Deletar cluster kind
kind delete cluster --name kind-istio
```

## Troubleshooting Rápido

### Pods não iniciam
```bash
kubectl -n istio-demo describe pod <pod-name>
kubectl -n istio-demo logs <pod-name> -c frontend
kubectl -n istio-demo logs <pod-name> -c istio-proxy
```

### Port-forward não conecta
```bash
# Matar todos port-forwards
pkill -f "kubectl.*port-forward"
# Reiniciar
make port-forward
```

### Jaeger sem traces
```bash
# Verificar telemetry
kubectl get telemetry -A
# Reiniciar apps
make restart-apps
# Gerar novo tráfego
make generate-traffic
```

### Grafana sem login
```bash
# Ver senha
kubectl -n istio-system get secrets prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 -d
```

## Próximos Passos

1. Importar dashboards Istio no Grafana (IDs: 7636, 7639, 7645)
2. Explorar traces no Jaeger
3. Criar queries personalizadas no Prometheus
4. Adicionar mais serviços à malha
5. Testar políticas de retry, circuit breaker, etc.
