# Helm Charts Agent Context

## Purpose

Official Helm charts for deploying Plane on Kubernetes.

## Chart Structure

```
charts/
  plane-ce/           # Community Edition (chart v1.5.0, app v1.2.3)
  plane-enterprise/   # Enterprise Edition (chart v2.3.0, app v2.5.2)
```

## Key Files

- `charts/plane-ce/values.yaml` — CE configuration values
- `charts/plane-enterprise/values.yaml` — Enterprise configuration values
- `charts/plane-ce/templates/` — CE Kubernetes manifests
- `charts/plane-enterprise/templates/` — Enterprise Kubernetes manifests
- `charts/{chart}/templates/ingress.yaml` — NGINX Ingress configuration
- `charts/{chart}/templates/ingress-traefik.yaml` — Traefik Ingress configuration

## Workloads

### Community Edition (CE)

Deployments: `web`, `api`, `worker`, `beat-worker`, `live`, `space`, `admin`
Jobs: `migrator`
Stateful: `postgres`, `redis`, `rabbitmq`, `minio`

### Enterprise Edition

Deployments: `web`, `api`, `worker`, `beat-worker`, `live`, `space`, `admin`,
`silo`, `email`, `iframely`, `outbox-poller`, `automation-consumer`,
`pi-api`, `pi-beat`, `pi-worker`
Jobs: `migrator`, `pi-migrator`
Stateful: `postgres`, `redis`, `rabbitmq`, `minio`, `opensearch`, `monitor`

## Enterprise-Only Features

- **Plane AI (PI)**: `pi-api`, `pi-beat`, `pi-worker`, `pi-migrator` — LLM integrations (OpenAI, Groq, Cohere, custom LLM, embedding models), separate AI Postgres DB (`pg_pi_db`)
- **Silo**: Connector service for Slack, GitHub, GitLab integrations
- **Automation consumer**: Event-driven workflow automation
- **Outbox poller**: Event synchronization / outbox pattern
- **Email service**: Dedicated email delivery service
- **Monitor**: Observability stateful service
- **Iframely**: Rich media embedding (optional)
- **OpenSearch**: In-cluster stateful deployment (also supportable externally)
- **License management**: `licenseServer` and `licenseDomain` configuration
- **Airgapped mode**: `airgapped:` block with S3 custom CA certificate support

## External Services Supported (both charts)

- RDS (external Postgres), ElastiCache (external Redis), SQS, S3-compatible storage

## Important Notes

- Ingress class configurable (`nginx`, `traefik`); both charts have Traefik middleware template
- CE values are flat per-service; Enterprise values use a hierarchical `services:` structure with additional secret keys (`opensearch_existingSecret`, `silo_env_existingSecret`, `pi_api_env_existingSecret`, `automations_consumer_env_existingSecret`)
- No OpenShift-specific templates in either chart
