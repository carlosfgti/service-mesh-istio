# Scripts

Coleção de scripts auxiliares para setup e gerenciamento do ambiente.

## Scripts disponíveis

### `create-kind.sh`
Cria um cluster kind com configuração personalizada para Istio.

```bash
./scripts/create-kind.sh [cluster-name]
# Padrão: kind-istio
```

### `install-observability.sh`
Instala stack de observabilidade (Grafana/Prometheus/Jaeger) via Helm.

```bash
./scripts/install-observability.sh
```

Instala:
- **kube-prometheus-stack**: Prometheus + Grafana + Alertmanager
- **Jaeger**: Distributed tracing (all-in-one mode)

### `setup-observability.sh`
Script completo que:
1. Verifica/instala Istio se necessário
2. Instala addons de observabilidade (Grafana/Prometheus/Jaeger)
3. Configura port-forwards automaticamente
4. Gera tráfego de teste

```bash
./scripts/setup-observability.sh
# Para parar os port-forwards:
./scripts/setup-observability.sh --stop
```

### `port-forward-dashboards.sh`
Inicia port-forwards para todos os dashboards.

```bash
./scripts/port-forward-dashboards.sh
# Para parar:
./scripts/port-forward-dashboards.sh --stop
```

Port-forwards criados:
- Grafana: http://localhost:3000
- Prometheus: http://localhost:9090
- Jaeger: http://localhost:16686
- Frontend (ingress): http://localhost:8080

### `generate-traffic.sh`
Gera tráfego HTTP de teste para popular métricas e traces.

```bash
./scripts/generate-traffic.sh [URL] [NUM_REQUESTS]
# Padrão: http://localhost:8080 50
```

## Fluxo de trabalho típico

1. Criar cluster:
```bash
make create-kind
```

2. Instalar Istio:
```bash
make install-istio
```

3. Build e deploy das aplicações:
```bash
make deploy
```

4. Instalar observabilidade:
```bash
make install-observability
```

5. Iniciar port-forwards:
```bash
make port-forward
```

6. Gerar tráfego:
```bash
make generate-traffic
```

7. Acessar dashboards:
- Grafana: http://localhost:3000 (admin / use `make` para ver senha)
- Prometheus: http://localhost:9090
- Jaeger: http://localhost:16686
