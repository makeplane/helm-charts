# Credential rotation runbook

How to rotate Plane's credentials without dropping requests, and which ones must never be rotated at all.

## How a rotation reaches a running pod

```
rotate in cloud secret store
        ↓  ESO polls, bounded by refreshInterval
Kubernetes Secret updated
        ↓  Reloader sees the change (needs reloader.enabled: true)
rolling restart, maxUnavailable: 0 / maxSurge: 1
        ↓
pods running with the new credential
```

Nothing in this chain is instant. Between the credential changing on the server and the new pods being ready, anything that opens a connection with the old credential fails — and Plane's Django services keep no persistent database connections, so in that window that is every request. Budget roughly `refreshInterval + rollout time`.

The fix is not a shorter interval. It is making **both the old and the new credential valid at the same time**, so the window stops mattering.

## Postgres — two-user alternation (zero window)

One-time setup:

```sql
CREATE ROLE plane_a LOGIN PASSWORD '<generated>';
CREATE ROLE plane_b LOGIN PASSWORD '<generated>';

-- identical grants for both
GRANT ALL PRIVILEGES ON DATABASE plane TO plane_a, plane_b;
GRANT ALL ON SCHEMA public TO plane_a, plane_b;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT ALL ON TABLES TO plane_a, plane_b;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT ALL ON SEQUENCES TO plane_a, plane_b;
```

To rotate, say the pods are currently on `plane_a`:

1. Change the password of the **idle** user: `ALTER ROLE plane_b PASSWORD '<new>';`
2. Update the cloud secret to `{"username": "plane_b", "password": "<new>"}`.
3. Wait for ESO to sync, then let Reloader roll the pods. `plane_a` stays valid throughout, so in-flight and newly opened connections keep working until the last old pod exits.
4. Confirm the rollout completed (`kubectl rollout status deploy/<release>-api-wl`), then optionally scramble `plane_a`'s password. It becomes the idle user for the next rotation.

Postgres does not terminate existing sessions when a role's password changes, so even a single-user rotation leaves established connections alive — but every *new* connection fails until the pods restart. The alternation is what removes that.

## RabbitMQ — second user (zero window)

Same shape. Create a second user with identical permissions on the vhost, rotate the idle one, switch the secret, let Reloader roll.

```bash
rabbitmqctl add_user plane_b '<generated>'
rabbitmqctl set_permissions -p / plane_b '.*' '.*' '.*'
```

On Amazon MQ, add the second user through the broker's user configuration; on a bundled `local_setup` broker this does not apply (see below).

## Redis

- **ElastiCache** — supports two simultaneously valid auth tokens. Use `ROTATE` to add the new token while the old one still works, point the secret at the new one, let Reloader roll, then `SET` to drop the old one.
- **Azure Cache for Redis** — the primary and secondary access keys are both always valid. Point the secret at the secondary, roll, then regenerate the primary.
- **Plain Redis / Valkey** — only one password exists, so a window is unavoidable. Use `refreshInterval: 30s` and rotate during low traffic. Django's cache is configured with `IGNORE_EXCEPTIONS`, so cache operations degrade instead of erroring, but throttling counters and the raw client paths will fail during the window.

## Credentials that must never be rotated

| Key | Why |
| --- | --- |
| `SECRET_KEY` | Derives the Fernet key encrypting the instance-configuration rows — SMTP password, OAuth client secrets, LLM keys, LDAP bind password. Rotating it makes every one of those rows undecryptable. |
| `AES_SECRET_KEY`, `AES_SALT` | Key material for the AES-256-GCM encryption protecting stored OAuth application secrets, MCP connections and desktop handoff tokens. |

Both fail **silently**: decryption errors are swallowed and the values come back empty, so the damage surfaces later as "SMTP stopped working" or "the GitHub integration lost its credentials". Keep them in a secret with no rotation policy — that is what `external_secrets.app_keys_existingSecret` is for. Changing them safely requires decrypting and re-encrypting the affected rows, which is a migration, not a rotation.

`LIVE_SERVER_SECRET_KEY`, `PI_INTERNAL_SECRET` and `SILO_HMAC_SECRET_KEY` *are* rotatable, but every service that uses one must change at the same time — which is why they belong in the single `app_keys` Secret rather than being duplicated across four.

## Things that will surprise you

**Jobs are not reloaded.** Reloader only restarts Deployments, StatefulSets and DaemonSets. The migrator Job runs with whatever credential existed when it started, so avoid rotating during an upgrade window; if a migration fails mid-rotation, re-run `helm upgrade`.

**The bundled `local_setup` infrastructure is out of scope.** The chart's own postgres/rabbitmq/minio/opensearch StatefulSets are intended for local and evaluation use; rotating their credentials means changing the password inside the container as well, which the chart does not orchestrate. Everything here assumes managed backends.

**Database-resident secrets do not rotate through the environment.** With the default `SKIP_ENV_VAR=1`, the SMTP password, OAuth client secrets, `LLM_API_KEY` and `LDAP_BIND_PASSWORD` live in the instance-configuration table, seeded from the environment only on first boot. Set `env.skip_env_var: '0'` to make the environment the source of truth on every restart — at the cost of god-mode admin UI edits to those settings being overwritten.

**Silo, live and Plane AI rotate like the API from planeVersion v3.2.0** — they read
discrete parts, so nothing recomposes a DSN and a Reloader restart is all that is needed.
Below v3.2.0 their DSN has to be composed by ESO with a `template` block (see the provider
examples), and that template embeds the password, so it must use `urlEncode`.

**Plane AI's follower connection re-reads its credentials at call time.** After an
authentication failure it refetches without waiting for a restart, so a remounted Secret
can take effect mid-process. Its own database and broker still resolve at import, so those
rely on the Reloader restart like everything else.

## Verifying a rotation

```bash
# 1. ESO actually synced
kubectl get externalsecret -n <ns> plane-rds \
  -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}{"\n"}'

# 2. The Secret holds the new value
kubectl get secret -n <ns> plane-rds -o jsonpath='{.data.password}' | base64 -d

# 3. Reloader rolled the workloads
kubectl rollout status -n <ns> deploy/<release>-api-wl
kubectl get pods -n <ns> -l app.name=<ns>-<release>-api

# 4. Nothing is failing to authenticate
kubectl logs -n <ns> deploy/<release>-api-wl --tail=100 \
  | grep -i "authentication failed\|OperationalError\|NOAUTH\|ACCESS_REFUSED"
```

If pods sit in `CreateContainerConfigError`, the Secret named in values does not exist yet — the chart references credential Secrets with `optional: false` deliberately, so a missing or not-yet-synced Secret fails loudly instead of starting a pod with no credentials.
