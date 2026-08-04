# External Secrets Operator examples

Ready-to-adapt manifests for feeding the `plane-enterprise` chart from a cloud secret store.

The chart consumes plain Kubernetes Secrets, so nothing here is chart-specific plumbing — it is ordinary External Secrets Operator configuration. Pick the file for your provider:

| File | Provider |
| --- | --- |
| [`aws-secrets-manager.yaml`](aws-secrets-manager.yaml) | AWS Secrets Manager (RDS / Amazon MQ / ElastiCache) |
| [`gcp-secret-manager.yaml`](gcp-secret-manager.yaml) | GCP Secret Manager (CloudSQL / Memorystore) |
| [`azure-key-vault.yaml`](azure-key-vault.yaml) | Azure Key Vault (Flexible Server / Cache for Redis) |
| [`rotation-runbook.md`](rotation-runbook.md) | How to rotate without dropping requests |

## The idea in one paragraph

A managed-rotation secret from RDS or CloudSQL contains only `{"username": "...", "password": "..."}`. Mirror it into the cluster **verbatim** with a plain `dataFrom.extract` — no `rewrite`, no `template` — and tell the chart which keys hold the username and password. The chart wires those keys into the pods as `POSTGRES_USER` / `POSTGRES_PASSWORD` and supplies the non-secret endpoint from `values.yaml`. The application composes its own connection URL from the parts, so **a rotation never requires recomposing a URL and there is only one secret to watch**.

```yaml
# values.yaml
external_secrets:
  database:
    secretName: plane-rds     # the mirrored secret
    usernameKey: username     # keys as they appear inside it
    passwordKey: password
env:
  pgdb_host: plane.abc123.eu-west-1.rds.amazonaws.com
  pgdb_name: plane
```

## Prerequisites

```bash
# External Secrets Operator
helm repo add external-secrets https://charts.external-secrets.io
helm install external-secrets external-secrets/external-secrets \
  -n external-secrets --create-namespace

# Stakater Reloader — restarts pods when a synced Secret changes.
# Without this a rotated credential never reaches a running pod.
helm repo add stakater https://stakater.github.io/stakater-charts
helm install reloader stakater/reloader -n reloader --create-namespace
```

Then in the chart's values:

```yaml
reloader:
  enabled: true
```

## Choosing refreshInterval

`refreshInterval` bounds how long a rotated credential stays unnoticed, and each interval costs one API call per `ExternalSecret` per provider.

- **`1h`** — the sensible default for secrets you rotate on a schedule and where you use the two-valid-credentials pattern from the runbook, so the window is harmless.
- **`1m`–`5m`** — when a single credential is swapped in place and the failure window must be short.

If your provider can push on rotation (an AWS Lambda rotation hook that annotates the `ExternalSecret`, or ESO's `PushSecret`/webhook paths), prefer that over polling frequently.

## What must never rotate

Do not put `SECRET_KEY`, `AES_SECRET_KEY` or `AES_SALT` in a secret with a rotation policy. `SECRET_KEY` derives the Fernet key encrypting the instance-configuration rows, and the AES pair protects stored OAuth/MCP tokens; changing either makes existing ciphertext undecryptable, silently. Keep them in a separate, static secret — that is what `app_keys_existingSecret` is for.
