# Service Mesh com Istio

Projeto de estudo sobre service mesh usando Istio. Criei dois microsserviços simples (frontend e product) pra testar tracing distribuído, métricas e toda a stack de observabilidade.

## O que tem aqui

Duas aplicações Flask bem básicas:
- **frontend** - faz request pro product e retorna os dados
- **product** - devolve uma lista de produtos (hardcoded mesmo, só pra testar)

Elas rodam num cluster kind com Istio, e você pode ver todas as métricas e traces no Grafana, Prometheus e Jaeger.

## Rodando local

Você vai precisar de:
- Docker Desktop rodando
- kubectl, kind, istioctl e helm instalados
- Paciência pra esperar os pods subirem 😅

### Setup rápido

Se quiser fazer tudo de uma vez (recomendo pra primeira vez):

```bash
# Cria o cluster kind
make create-kind

# Instala o Istio já com tracing configurado
make install-istio

# Builda as imagens e faz deploy
make build-images
make kind-load
make apply

# Instala a stack de observabilidade (Grafana, Prometheus, Jaeger)
make install-observability

# Aguarda tudo subir (pode levar uns 2-3 min)
kubectl -n istio-demo get pods -w

# Inicia os port-forwards pros dashboards
make port-forward

# Gera uns requests pra ter dados nos dashboards
make generate-traffic
```

### Acessando

Depois que tudo subir:

- **Aplicação**: http://localhost:8080
- **Grafana**: http://localhost:3000 (user: admin, senha: roda `kubectl -n istio-system get secrets prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 -d`)
- **Prometheus**: http://localhost:9090
- **Jaeger**: http://localhost:16686

No Jaeger, procura pelo service `frontend.istio-demo` pra ver os traces das requisições.

## Comandos úteis

```bash
# Ver o status de tudo
make status

# Gerar mais tráfego
make generate-traffic

# Reiniciar as apps (útil quando muda alguma config do Istio)
make restart-apps

# Ver todos os comandos disponíveis
make help

# Parar os port-forwards
bash scripts/port-forward-dashboards.sh --stop
```

## Como funciona

O frontend chama o product através do service mesh. O Istio injeta um sidecar (Envoy proxy) em cada pod, e esse proxy intercepta todo o tráfego HTTP. Por isso dá pra ver as métricas de latência, taxa de erro, e os traces distribuídos de cada request.

O tracing tá configurado pra capturar 100% das requisições (não é recomendado em produção, mas pra testar é bom). Os proxies mandam os spans pro Jaeger usando o protocolo Zipkin.

## Troubleshooting

**Pods não sobem (ImagePullBackOff)**
```bash
make build-images
make kind-load
kubectl -n istio-demo rollout restart deployment frontend product
```

**Jaeger não mostra traces**
```bash
# Verifica se o telemetry tá aplicado
kubectl get telemetry -A

# Reinicia as apps pra pegar a config nova
make restart-apps

# Gera tráfego novo
make generate-traffic
```

**Port-forward não funciona**
```bash
pkill -f "kubectl.*port-forward"
make port-forward
```

## Docs extras

- [QUICKSTART.md](docs/QUICKSTART.md) - guia completo do zero até funcionar
- [SETUP.md](docs/SETUP.md) - detalhes técnicos de todas as configs
- [retry-policy.md](docs/retry-policy.md) - como configurar e testar retry no Istio
- [scripts.md](docs/scripts.md) - docs dos scripts auxiliares
