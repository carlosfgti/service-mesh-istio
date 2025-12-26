# Service Mesh Demo com Istio e Observabilidade

Exemplo mínimo de service mesh usando Istio com observabilidade (Prometheus, Grafana, Jaeger via perfil `demo` do Istio).

Pré-requisitos
- Cluster Kubernetes (minikube, kind, ou um cluster remoto)
- `kubectl` configurado para o cluster
- `docker` para build de imagens (ou `podman`)
- `istioctl` para instalar Istio

Passos rápidos

1. Instalar Istio (perfil demo):

```bash
chmod +x install-istio.sh
./install-istio.sh
```

2. Construir imagens e aplicar manifests:

```bash
make build-images
chmod +x deploy.sh
./deploy.sh
```

3. Acessar dashboards de observabilidade (após a instalação do Istio):

```bash
istioctl dashboard prometheus
istioctl dashboard grafana
istioctl dashboard jaeger

Observability (script automatizado)
 - Há um script que automatiza a instalação dos addons (Grafana/Prometheus/Jaeger quando necessário), faz port-forward dos serviços e gera tráfego de teste:

```bash
chmod +x scripts/setup-observability.sh
./scripts/setup-observability.sh
```

 - Para interromper os port-forwards que o script iniciou:

```bash
./scripts/setup-observability.sh --stop
```

Kind helpers
 - Existe um arquivo de configuração para `kind` e um script para criar o cluster e carregar imagens locais:

```bash
kind create cluster --config kind-config.yaml --name kind-istio
# ou via helper
bash scripts/create-kind.sh
```

```

Notas para clusters locais
- Para `kind`, carregue as imagens locais com:

```bash
# após `make build-images`
kind load docker-image frontend:demo --name <kind-cluster>
kind load docker-image product:demo --name <kind-cluster>
```

Como funciona
- `frontend` consulta `product` em `/products`.
- Ambos os deployments são implantados no namespace `istio-demo` com `istio-injection=enabled`.
- O `Gateway` do Istio expõe o `frontend` via ingress.

Próximos passos
- Posso ajustar os manifests para `minikube` (NodePort) ou adicionar recursos de telemetria mais avançados (mTLS, DestinationRule). Quer que eu faça isso?

Acessando aplicações e observability

- Frontend (aplicação):
	- Se o `istio-ingressgateway` expuser um IP externo:

```bash
kubectl -n istio-system get svc istio-ingressgateway
# supondo EXTERNAL-IP em GATEWAY_IP:
curl http://<GATEWAY_IP>/
```

	- Para clusters locais (kind/minikube) ou quando não houver IP externo, use port-forward:

```bash
kubectl -n istio-system port-forward svc/istio-ingressgateway 8080:80
# então no outro terminal:
curl http://localhost:8080/
```

- Dashboards (Grafana / Prometheus / Jaeger):
	- Se usou `scripts/setup-observability.sh`, os port-forwards já estarão ativos localmente:
		- Grafana: http://localhost:3000
		- Prometheus: http://localhost:30900
		- Jaeger: http://localhost:16686

	- Para abrir via `istioctl` (quando os addons estão instalados como parte do Istio):

```bash
istioctl dashboard prometheus
istioctl dashboard grafana
istioctl dashboard jaeger
```

	- Se precisar de credencial admin do Grafana (release `grafana`):

```bash
kubectl -n istio-system get secret grafana -o jsonpath="{.data.admin-password}" | base64 -d
# usuário: admin
```

- Consultas úteis no Prometheus (exemplos):

```text
# taxa de requisições por workload
rate(istio_requests_total[1m])

# latência p95 por workload
histogram_quantile(0.95, sum(rate(istio_request_duration_seconds_bucket[5m])) by (le, destination_workload))
```

- Ver traces no Jaeger: abra http://localhost:16686, procure por `frontend` ou `product` e visualize um trace.

- Gerar tráfego de teste (útil para popular métricas/traces):

```bash
for i in {1..50}; do curl -s http://localhost:8080/ >/dev/null; done
```

- Parar port-forwards iniciados pelo script `setup-observability.sh`:

```bash
./scripts/setup-observability.sh --stop
# ou manualmente:
xargs -a /tmp/istio-observability-pids.txt -r kill || true
rm -f /tmp/istio-observability-pids.txt
```

Se algum serviço (ex.: `grafana`) não estiver presente em `istio-system`, cole a saída de:

```bash
kubectl -n istio-system get pods,svc,deploy
```

que eu ajudo a corrigir.
