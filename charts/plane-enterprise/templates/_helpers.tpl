{{- define "imagePullSecret" }}
{{- printf "{\"auths\":{\"%s\":{\"username\":\"%s\",\"password\":\"%s\"}}}" .Values.dockerRegistry.registry .Values.dockerRegistry.loginid .Values.dockerRegistry.password | b64enc }}
{{- end }}

{{- define "hashString" -}}
{{- printf "%s%s%s%s" .Values.license.licenseServer .Values.license.licenseDomain .Release.Namespace .Release.Name | sha256sum  -}}
{{- end -}}

{{- define "plane.podScheduling" -}}
  {{- with .nodeSelector }} 
      nodeSelector: {{ toYaml . | nindent 8 }}
  {{- end }}
  {{- with .tolerations }}
      tolerations: {{ toYaml . | nindent 8 }}
  {{- end }}
  {{- with .affinity }}
      affinity: {{ toYaml . | nindent 8 }}
  {{- end }}
{{- end }}

{{/*
Pod-level securityContext. Rendered only when securityContext.enabled is true.
Mirrors the kustomize nonroot-security-context component (pod patch).
Place inside spec.template.spec — call with the root context, e.g.
  {{- include "plane.podSecurityContext" . }}
*/}}
{{- define "plane.podSecurityContext" -}}
{{- if .Values.securityContext.enabled }}
      securityContext: {{- toYaml .Values.securityContext.podSecurityContext | nindent 8 }}
{{- end }}
{{- end -}}

{{/*
Container-level securityContext. Rendered only when securityContext.enabled is true.
Mirrors the kustomize nonroot-security-context component (container patch).
Place inside a container/initContainer entry — call with the root context, e.g.
  {{- include "plane.containerSecurityContext" . }}
*/}}
{{- define "plane.containerSecurityContext" -}}
{{- if .Values.securityContext.enabled }}
        securityContext: {{- toYaml .Values.securityContext.containerSecurityContext | nindent 10 }}
{{- end }}
{{- end -}}

{{/*
Chart name and version, sanitized for use as the `helm.sh/chart` label value.
*/}}
{{- define "plane.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Standard Kubernetes recommended labels shared by every resource the chart renders.
These are additive metadata labels only; they are intentionally kept out of
spec.selector/matchLabels (which stay on the immutable `app.name` label) so that
upgrading an existing release never tries to mutate an immutable selector.
Call with the root context, e.g. {{ include "plane.commonLabels" $ }}
*/}}
{{- define "plane.commonLabels" -}}
helm.sh/chart: {{ include "plane.chart" . }}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- with .Chart.AppVersion }}
app.kubernetes.io/version: {{ . | quote }}
{{- end }}
{{- end -}}

{{/*
Render a resource's `labels` and `annotations` metadata.
Always emits the standard recommended labels (see plane.commonLabels) and merges
any per-component labels supplied under the component's `labels` value. Per-component
annotations are emitted when present.
Call with a dict carrying the root context and the component values:
  {{ include "plane.labelsAndAnnotations" (dict "context" $ "values" .Values.services.api) }}
*/}}
{{- define "plane.labelsAndAnnotations" }}
  labels:
    {{- include "plane.commonLabels" .context | nindent 4 }}
    {{- with .values.labels }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
  {{- /*
  Reloader reads its annotation from the workload resource, not the pod template,
  so it is merged in here rather than emitted alongside the per-component
  annotations — a second literal `annotations:` key would silently shadow one of
  the two. A component-level annotation of the same name still wins.
  */}}
  {{- $annotations := deepCopy (default dict .values.annotations) }}
  {{- if .context.Values.reloader.enabled }}
  {{- $annotations = merge $annotations (dict "reloader.stakater.com/auto" "true") }}
  {{- end }}
  {{- with $annotations }}
  annotations: {{ toYaml . | nindent 4 }}
  {{- end }}
{{- end }}

{{/*
Returns "true" when the bundled MinIO should be deployed.
MinIO is deployed only when services.minio.local_setup is enabled AND the storage
provider is not GCS — GCS native mode never uses the bundled MinIO, so selecting it
must disable the MinIO StatefulSet, bucket job, ingress routes and certs regardless
of the local_setup flag's value.
*/}}
{{- define "plane.minioEnabled" -}}
  {{- if and .Values.services.minio.local_setup (ne (.Values.env.storage_provider | default "S3" | upper) "GCS") -}}
    true
  {{- end -}}
{{- end -}}

{{/*
Normalize the deprecated s3SecretName/s3SecretKey into the s3Secrets list format.
Returns "true" when airgapped is enabled and at least one CA secret is configured.
*/}}
{{- define "plane.s3CAEnabled" -}}
  {{- if and .Values.airgapped.enabled (or (gt (len .Values.airgapped.s3Secrets) 0) (and .Values.airgapped.s3SecretName .Values.airgapped.s3SecretKey)) -}}
    true
  {{- end -}}
{{- end -}}

{{/*
Render the volumes block for custom S3 CA certificates.
Always uses a projected volume so both single-secret (legacy) and multi-secret configs
produce the same volume structure.
Caller must nindent to the correct depth.
*/}}
{{- define "plane.s3CAVolumes" -}}
{{- if include "plane.s3CAEnabled" . -}}
volumes:
  - name: s3-custom-ca
    projected:
      sources:
      {{- if gt (len .Values.airgapped.s3Secrets) 0 }}
      {{- range .Values.airgapped.s3Secrets }}
      - secret:
          name: {{ .name }}
          items:
            - key: {{ .key }}
              path: {{ .key }}
      {{- end }}
      {{- else }}
      - secret:
          name: {{ .Values.airgapped.s3SecretName }}
          items:
            - key: {{ .Values.airgapped.s3SecretKey }}
              path: {{ .Values.airgapped.s3SecretKey }}
      {{- end }}
{{- end }}
{{- end -}}

{{/*
Render the volumeMounts block for custom S3 CA certificates.
Caller must nindent to the correct depth.
*/}}
{{- define "plane.s3CAVolumeMounts" -}}
{{- if include "plane.s3CAEnabled" . -}}
volumeMounts:
  - name: s3-custom-ca
    mountPath: /s3-custom-ca
    readOnly: true
{{- end }}
{{- end -}}

{{/*
Render the shell init script that installs custom CA certificates.
Output is raw shell; caller embeds it inside the command block.
*/}}
{{- define "plane.s3CAInitScript" -}}
{{- if include "plane.s3CAEnabled" . -}}
echo "Installing custom CA certificates..."
mkdir -p /usr/local/share/ca-certificates
if [ "$(ls -A /s3-custom-ca)" ]; then
  echo "Found certificates in /s3-custom-ca. Installing..."
  cp /s3-custom-ca/* /usr/local/share/ca-certificates/
  update-ca-certificates
  echo "CA certificates installed successfully"
else
  echo "No custom S3 CA certificate found, skipping..."
fi
{{- end }}
{{- end -}}

{{/*
Render the SSL/TLS env vars needed when custom CA certs are installed.
Caller must nindent to the correct depth.
*/}}
{{- define "plane.s3CAEnvVars" -}}
{{- if include "plane.s3CAEnabled" . -}}
- name: SSL_CERT_FILE
  value: "/etc/ssl/certs/ca-certificates.crt"
- name: SSL_CERT_DIR
  value: "/etc/ssl/certs"
- name: REQUESTS_CA_BUNDLE
  value: "/etc/ssl/certs/ca-certificates.crt"
- name: CURL_CA_BUNDLE
  value: "/etc/ssl/certs/ca-certificates.crt"
{{- end }}
{{- end -}}

{{/*
Render the volumes block for Node.js services that use the init container CA pattern.
Includes both the projected CA secret volume and a shared emptyDir for the bundled output.
Caller must nindent to the correct depth.
*/}}
{{- define "plane.s3CANodeVolumes" -}}
{{- if include "plane.s3CAEnabled" . -}}
volumes:
  - name: s3-custom-ca
    projected:
      sources:
      {{- if gt (len .Values.airgapped.s3Secrets) 0 }}
      {{- range .Values.airgapped.s3Secrets }}
      - secret:
          name: {{ .name }}
          items:
            - key: {{ .key }}
              path: {{ .key }}
      {{- end }}
      {{- else }}
      - secret:
          name: {{ .Values.airgapped.s3SecretName }}
          items:
            - key: {{ .Values.airgapped.s3SecretKey }}
              path: {{ .Values.airgapped.s3SecretKey }}
      {{- end }}
  - name: ca-bundle
    emptyDir: {}
{{- end }}
{{- end -}}

{{/*
Render the volumeMount for the shared CA bundle emptyDir on the main container.
Caller must nindent to the correct depth.
*/}}
{{- define "plane.s3CANodeBundleMount" -}}
{{- if include "plane.s3CAEnabled" . -}}
volumeMounts:
  - name: ca-bundle
    mountPath: /ca-bundle
    readOnly: true
{{- end }}
{{- end -}}

{{/*
Render env vars for Node.js containers when custom CA certs are installed.
NODE_EXTRA_CA_CERTS tells Node.js to trust additional CAs on top of its built-in bundle.
Caller must nindent to the correct depth.
*/}}
{{- define "plane.s3CANodeEnvVars" -}}
{{- if include "plane.s3CAEnabled" . -}}
- name: NODE_EXTRA_CA_CERTS
  value: "/ca-bundle/custom-ca-bundle.crt"
{{- end }}
{{- end -}}

{{/*
================================================================================
ServiceAccount
================================================================================
*/}}

{{/*
Name of the ServiceAccount every workload runs as. Defaults to the release-scoped
account the chart creates; override with serviceAccount.name to run as a
ServiceAccount you manage yourself (e.g. one created by Crossplane/Terraform and
already bound to a cloud IAM role, or an EKS Pod Identity association target).
*/}}
{{- define "plane.serviceAccountName" -}}
{{- .Values.serviceAccount.name | default (printf "%s-srv-account" .Release.Name) -}}
{{- end -}}

{{/*
Returns "true" when the chart should render the ServiceAccount itself.
Skipped when serviceAccount.create is false — i.e. the account is managed outside
the chart (GitOps, Terraform) and only referenced here.
*/}}
{{- define "plane.createServiceAccount" -}}
{{- if .Values.serviceAccount.create -}}
true
{{- end -}}
{{- end -}}

{{/*
Pod-template labels required by some workload-identity implementations
(notably Azure Workload Identity, which needs azure.workload.identity/use: "true"
on the pod). Indentation is baked in for the pod-template label position, so call it
bare: {{- include "plane.serviceAccountPodLabels" . }}
*/}}
{{- define "plane.serviceAccountPodLabels" -}}
{{- with .Values.serviceAccount.podLabels }}
{{- toYaml . | nindent 8 }}
{{- end }}
{{- end -}}

{{/*
================================================================================
Rollout: config checksum + Reloader
================================================================================
*/}}

{{/*
Aggregate sha256 over every Secret/ConfigMap the chart renders from values.
Used as a pod-template annotation so `helm upgrade` rolls workloads when — and
only when — chart-rendered configuration actually changed. Secrets that live
outside the chart (External Secrets Operator, sealed secrets, manual) are not
visible here by design: rotation of those is Reloader's job, see
plane.reloaderAnnotations.

The hash intentionally covers all config-secret templates rather than a per-workload
subset: several keys (AES_SECRET_KEY, LIVE_SERVER_SECRET_KEY, PI_INTERNAL_SECRET)
must stay in lockstep across services, so a shared trigger is the safe default.
*/}}
{{- define "plane.configChecksum" -}}
{{- $ctx := . -}}
{{- $acc := "" -}}
{{- range $f := list "app-env" "pgdb" "rabbitmqdb" "doc-store" "opensearchdb" "live-env" "silo" "pi-api-env" "runner-env" "email-env" "monitor" "outbox-poller" "webhook-consumer" "automations-consumer" "agent-consumer" -}}
{{- $acc = print $acc (include (print $ctx.Template.BasePath "/config-secrets/" $f ".yaml") $ctx) -}}
{{- end -}}
{{- $acc | sha256sum -}}
{{- end -}}

{{/*
Pod-template annotations shared by every workload.

  checksum/config   always — rolls the pod when chart-rendered config changes
  timestamp         only when global.forceRedeploy — restores the pre-3.1 behaviour
                    of rolling every workload on every upgrade

The Reloader annotation is NOT here: Reloader watches the workload resource's own
annotations, so it is merged into plane.labelsAndAnnotations instead.

Call with the root context. Caller must nindent to the correct depth.
*/}}
{{- define "plane.podAnnotations" -}}
checksum/config: {{ include "plane.configChecksum" . | quote }}
{{- if .Values.global.forceRedeploy }}
timestamp: {{ now | quote }}
{{- end }}
{{- end -}}

{{/*
Rolling-update strategy that keeps full capacity during a rollout, so a
Reloader-triggered restart after a credential rotation never drops requests.
Rendered only for replicated Deployments (surge needs room to schedule).
Caller must nindent to the correct depth.
*/}}
{{- define "plane.rollingUpdateStrategy" -}}
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxUnavailable: 0
    maxSurge: 1
{{- end -}}

{{/*
================================================================================
Externalized secret values
================================================================================
*/}}

{{/*
Resolve a secret value with an optional insecure fallback.

Returns .value when set. Otherwise fails the render when env.requireExplicitSecrets
is true, and falls back to .fallback when it is false (the pre-3.1 behaviour, kept
so existing installs keep working). The fallback values shipped by this chart are
PUBLIC CONSTANTS — any production install must supply its own.

Call with a dict: (dict "context" $ "name" "SECRET_KEY" "value" .Values.env.secret_key "fallback" "...")
*/}}
{{- define "plane.secretValue" -}}
{{- if .value -}}
{{- .value -}}
{{- else if .context.Values.env.requireExplicitSecrets -}}
{{- required (printf "%s has no value. Set it in values.yaml, or supply it through external_secrets.app_keys_existingSecret, or set env.requireExplicitSecrets=false to fall back to the chart's insecure default." .name) nil -}}
{{- else -}}
{{- .fallback -}}
{{- end -}}
{{- end -}}

{{/*
envFrom entry for the Secret carrying the shared signing/encryption keys
(SECRET_KEY, AES_SECRET_KEY, AES_SALT, LIVE_SERVER_SECRET_KEY, PI_INTERNAL_SECRET,
SILO_HMAC_SECRET_KEY, CURSOR_WEBHOOK_SECRET). Renders nothing unless
external_secrets.app_keys_existingSecret is set.

These keys are duplicated across the api, live, silo and pi Secrets, and several of
them must agree for those services to talk to each other. Pointing all of them at
one Secret makes that agreement structural instead of something an operator has to
remember to update in four places. When it is in use the chart stops emitting those
keys in its own Secrets, so this is their only source.

Placed first in envFrom so that a key you have already externalized through one of
the older *_existingSecret groups keeps taking precedence.

Indentation is baked in for the container envFrom position, so call it bare:
{{- include "plane.appKeysSecretRef" . }}
*/}}
{{- define "plane.appKeysSecretRef" -}}
{{- with .Values.external_secrets.app_keys_existingSecret }}
          - secretRef:
              name: {{ . }}
              optional: false
{{- end }}
{{- end -}}

{{/*
envFrom entry for the Secret carrying the AI/LLM provider keys. Renders nothing
unless external_secrets.ai_providers_existingSecret is set.

Separate from the Plane AI Secret because provider accounts are shared across
environments while everything else in that Secret is per-environment. Mounted on the
Plane AI workloads and on live (whose AI_OPENAI_API_KEY has no values key at all).

Placed before the chart's own Secret so an operator who has already externalized
pi_api_env keeps that precedence. While this is set the chart emits none of these
keys itself — including the empty-string branches, which would otherwise overwrite
this Secret's values, since envFrom resolves later-source-wins.

Indentation is baked in for the container envFrom position, so call it bare.
*/}}
{{- define "plane.aiProvidersSecretRef" -}}
{{- with .Values.external_secrets.ai_providers_existingSecret }}
          - secretRef:
              name: {{ . }}
              optional: false
{{- end }}
{{- end -}}

{{/*
envFrom entry for the Secret carrying the silo connector credentials. Renders nothing
unless external_secrets.silo_connectors_existingSecret is set.

Mounted on every workload that mounts silo-secrets today, not just silo: the Django
auth adapter reads GITHUB_CLIENT_ID/GITHUB_CLIENT_SECRET from that Secret on the api
family, so mounting this only on silo would drop those variables there.

Indentation is baked in for the container envFrom position, so call it bare.
*/}}
{{- define "plane.siloConnectorsSecretRef" -}}
{{- with .Values.external_secrets.silo_connectors_existingSecret }}
          - secretRef:
              name: {{ . }}
              optional: false
{{- end }}
{{- end -}}

{{/*
Returns "true" when an externally managed Secret supplies the Postgres credentials,
in which case the chart must not render a composed DATABASE_URL that would take
precedence over the discrete POSTGRES_* parts.
*/}}
{{- define "plane.externalDatabase" -}}
{{- if .Values.external_secrets.database.secretName -}}
true
{{- end -}}
{{- end -}}

{{- define "plane.externalRabbitmq" -}}
{{- if .Values.external_secrets.rabbitmq.secretName -}}
true
{{- end -}}
{{- end -}}

{{- define "plane.externalRedis" -}}
{{- if .Values.external_secrets.redis.secretName -}}
true
{{- end -}}
{{- end -}}

{{/*
Only meaningful for a remote OpenSearch: when the chart runs the bundled cluster it
owns those credentials on both sides, so externalizing just the application's half
would leave the two disagreeing. Use opensearch_existingSecret for that case.
*/}}
{{- define "plane.externalOpensearch" -}}
{{- if and .Values.external_secrets.opensearch.secretName (not .Values.services.opensearch.local_setup) -}}
true
{{- end -}}
{{- end -}}

{{/*
Postgres host/port/database the app should connect to in externalized-credential
mode. Endpoint details are not secret, so they come from values (or from the
mirrored cloud secret when it happens to carry them — see hostKey/portKey/dbNameKey).
*/}}
{{- define "plane.postgresHost" -}}
{{- if .Values.services.postgres.local_setup -}}
{{- printf "%s-pgdb.%s.svc.%s" .Release.Name .Release.Namespace (.Values.env.default_cluster_domain | default "cluster.local") -}}
{{- else -}}
{{- .Values.env.pgdb_host -}}
{{- end -}}
{{- end -}}

{{- define "plane.rabbitmqHost" -}}
{{- if .Values.services.rabbitmq.local_setup -}}
{{- printf "%s-rabbitmq.%s.svc.%s" .Release.Name .Release.Namespace (.Values.env.default_cluster_domain | default "cluster.local") -}}
{{- else -}}
{{- .Values.env.rabbitmq_host -}}
{{- end -}}
{{- end -}}

{{- define "plane.redisHost" -}}
{{- if .Values.services.redis.local_setup -}}
{{- printf "%s-redis.%s.svc.%s" .Release.Name .Release.Namespace (.Values.env.default_cluster_domain | default "cluster.local") -}}
{{- else -}}
{{- .Values.env.redis_host -}}
{{- end -}}
{{- end -}}

{{/*
Emit one env entry sourced from a key inside an externally managed Secret.
Call with a dict: (dict "name" "POSTGRES_USER" "secret" $name "key" $key)

Emits a leading newline so that call sites can use a left-trim marker
({{- include ... }}) without swallowing the separator from the previous entry.
*/}}
{{- define "plane.secretKeyEnv" }}
- name: {{ .name }}
  valueFrom:
    secretKeyRef:
      name: {{ .secret }}
      key: {{ .key }}
{{- end -}}

{{/*
Discrete infrastructure credentials for the Django services (api, workers,
consumers, poller, migrator). Renders nothing unless at least one of
external_secrets.{database,redis,rabbitmq}.secretName is set.

Design: the cluster Secret is a verbatim mirror of the cloud secret — an RDS or
CloudSQL managed-rotation secret holds only {"username","password"} — so the chart
maps whatever keys that secret happens to use onto the env var names the app reads,
and takes the non-secret endpoint (host/port/database) from values. Nothing needs
templating or recomposing on rotation, and there is exactly one secret to watch.

The app composes its own connection URLs from these parts, so a rotated password
propagates with no URL rewriting anywhere in the chain.

Caller must indent to the correct depth (env list items).
*/}}
{{- define "plane.infraCredsEnv" -}}
{{- include "plane.postgresCredsEnv" . }}
{{- include "plane.rabbitmqCredsEnv" . }}
{{- include "plane.redisCredsEnv" . }}
{{- include "plane.opensearchCredsEnv" . }}
{{- include "plane.storageCredsEnv" . }}
{{- end -}}

{{/*
Postgres credentials from an externally managed Secret. Split out of
plane.infraCredsEnv so a workload can take only the backends it actually uses —
the live server needs Redis and nothing else.
*/}}
{{- define "plane.postgresCredsEnv" -}}
{{- $db := .Values.external_secrets.database -}}
{{- if $db.secretName }}
- name: POSTGRES_HOST
  value: {{ include "plane.postgresHost" . | quote }}
- name: POSTGRES_PORT
  value: {{ .Values.env.pgdb_port | default "5432" | quote }}
- name: POSTGRES_DB
  value: {{ .Values.env.pgdb_name | default "plane" | quote }}
{{- include "plane.secretKeyEnv" (dict "name" "POSTGRES_USER" "secret" $db.secretName "key" ($db.usernameKey | default "username")) }}
{{- include "plane.secretKeyEnv" (dict "name" "POSTGRES_PASSWORD" "secret" $db.secretName "key" ($db.passwordKey | default "password")) }}
{{- with $db.hostKey }}
{{- include "plane.secretKeyEnv" (dict "name" "POSTGRES_HOST" "secret" $db.secretName "key" .) }}
{{- end }}
{{- with $db.portKey }}
{{- include "plane.secretKeyEnv" (dict "name" "POSTGRES_PORT" "secret" $db.secretName "key" .) }}
{{- end }}
{{- with $db.dbNameKey }}
{{- include "plane.secretKeyEnv" (dict "name" "POSTGRES_DB" "secret" $db.secretName "key" .) }}
{{- end }}
{{- end }}
{{- include "plane.postgresReadReplicaCredsEnv" . }}
{{- end -}}

{{/*
Returns "true" when object-storage credentials come from an externally managed Secret.
Never true while the bundled MinIO is deployed — that supplies its own credentials, and
overriding them would break the in-cluster client.
*/}}
{{- define "plane.externalStorage" -}}
{{- if and .Values.external_secrets.storage.secretName (not (include "plane.minioEnabled" .)) -}}
true
{{- end -}}
{{- end -}}

{{/*
Object-storage credentials as explicit env entries, so they win over the doc-store
Secret mounted via envFrom.

Only the keys the operator names are emitted: an S3 deployment sets the two access-key
keys, a GCS deployment sets gcsCredentialsJsonKey, and a deployment using a pod identity
sets none of them and relies on the SDK credential chain.

Caller must indent to the correct depth (env list items).
*/}}
{{- define "plane.storageCredsEnv" -}}
{{- $st := .Values.external_secrets.storage -}}
{{- if include "plane.externalStorage" . }}
{{- with $st.accessKeyIdKey }}
{{- include "plane.secretKeyEnv" (dict "name" "AWS_ACCESS_KEY_ID" "secret" $st.secretName "key" .) }}
{{- end }}
{{- with $st.secretAccessKeyKey }}
{{- include "plane.secretKeyEnv" (dict "name" "AWS_SECRET_ACCESS_KEY" "secret" $st.secretName "key" .) }}
{{- end }}
{{- with $st.gcsCredentialsJsonKey }}
{{- include "plane.secretKeyEnv" (dict "name" "GCS_CREDENTIALS_JSON" "secret" $st.secretName "key" .) }}
{{- end }}
{{- end }}
{{- end -}}

{{/*
Returns "true" when the read replica's credentials come from an externally managed
Secret. Falls back to the primary's Secret, since a replica normally accepts the same
credential — set readReplica.secretName only when it has its own user.
*/}}
{{- define "plane.externalReadReplica" -}}
{{- if .Values.services.postgres.read_replica.enabled -}}
{{- if or .Values.external_secrets.database.readReplica.secretName .Values.external_secrets.database.secretName -}}
true
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Read-replica credentials as discrete parts.

services.postgres.read_replica.remote_url is a DSN carrying the password, so a managed
rotation can never update it. The API reads POSTGRES_READ_REPLICA_* natively — Django
takes the parts straight into a config dict, so nothing composes a URL — which makes
this a chart-only change.

Caller must indent to the correct depth (env list items).
*/}}
{{- define "plane.postgresReadReplicaCredsEnv" -}}
{{- $db := .Values.external_secrets.database -}}
{{- $rr := $db.readReplica -}}
{{- $secret := $rr.secretName | default $db.secretName -}}
{{/* The newline after this `if` is deliberate: call sites use a left-trim marker, so
     the output has to open with one to keep this entry off the previous line. */}}
{{- if include "plane.externalReadReplica" . }}
- name: POSTGRES_READ_REPLICA_HOST
  value: {{ .Values.env.pgdb_read_replica_host | quote }}
- name: POSTGRES_READ_REPLICA_PORT
  value: {{ .Values.env.pgdb_read_replica_port | default "5432" | quote }}
- name: POSTGRES_READ_REPLICA_DB
  value: {{ .Values.env.pgdb_read_replica_name | default .Values.env.pgdb_name | default "plane" | quote }}
{{- include "plane.secretKeyEnv" (dict "name" "POSTGRES_READ_REPLICA_USER" "secret" $secret "key" ($rr.usernameKey | default $db.usernameKey | default "username")) }}
{{- include "plane.secretKeyEnv" (dict "name" "POSTGRES_READ_REPLICA_PASSWORD" "secret" $secret "key" ($rr.passwordKey | default $db.passwordKey | default "password")) }}
{{- with $rr.hostKey }}
{{- include "plane.secretKeyEnv" (dict "name" "POSTGRES_READ_REPLICA_HOST" "secret" $secret "key" .) }}
{{- end }}
{{- with $rr.portKey }}
{{- include "plane.secretKeyEnv" (dict "name" "POSTGRES_READ_REPLICA_PORT" "secret" $secret "key" .) }}
{{- end }}
{{- with $rr.dbNameKey }}
{{- include "plane.secretKeyEnv" (dict "name" "POSTGRES_READ_REPLICA_DB" "secret" $secret "key" .) }}
{{- end }}
{{- end }}
{{- end -}}

{{/*
RabbitMQ credentials from an externally managed Secret.
*/}}
{{- define "plane.rabbitmqCredsEnv" -}}
{{- $mq := .Values.external_secrets.rabbitmq -}}
{{- if $mq.secretName }}
- name: RABBITMQ_HOST
  value: {{ include "plane.rabbitmqHost" . | quote }}
- name: RABBITMQ_PORT
  value: {{ .Values.env.rabbitmq_port | default "5672" | quote }}
- name: RABBITMQ_VHOST
  value: {{ .Values.env.rabbitmq_vhost | default "/" | quote }}
- name: RABBITMQ_SSL
  {{/* The parts path has no URL scheme to carry TLS, so it needs an explicit flag.
       Amazon MQ for RabbitMQ listens on 5671 and refuses plaintext. */}}
  value: {{ .Values.env.rabbitmq_ssl | default false | ternary "1" "0" | quote }}
{{- include "plane.secretKeyEnv" (dict "name" "RABBITMQ_USER" "secret" $mq.secretName "key" ($mq.usernameKey | default "username")) }}
{{- include "plane.secretKeyEnv" (dict "name" "RABBITMQ_PASSWORD" "secret" $mq.secretName "key" ($mq.passwordKey | default "password")) }}
{{- with $mq.hostKey }}
{{- include "plane.secretKeyEnv" (dict "name" "RABBITMQ_HOST" "secret" $mq.secretName "key" .) }}
{{- end }}
{{- with $mq.portKey }}
{{- include "plane.secretKeyEnv" (dict "name" "RABBITMQ_PORT" "secret" $mq.secretName "key" .) }}
{{- end }}
{{- with $mq.vhostKey }}
{{- include "plane.secretKeyEnv" (dict "name" "RABBITMQ_VHOST" "secret" $mq.secretName "key" .) }}
{{- end }}
{{- end }}
{{- end -}}

{{/*
Redis credentials from an externally managed Secret. Consumed on its own by the
live server, and by Plane AI, whose Celery broker is Redis in Helm deployments.
*/}}
{{- define "plane.redisCredsEnv" -}}
{{- $redis := .Values.external_secrets.redis -}}
{{- if $redis.secretName }}
- name: REDIS_HOST
  value: {{ include "plane.redisHost" . | quote }}
- name: REDIS_PORT
  value: {{ .Values.env.redis_port | default "6379" | quote }}
- name: REDIS_SSL
  value: {{ .Values.env.redis_ssl | default false | ternary "1" "0" | quote }}
{{- include "plane.secretKeyEnv" (dict "name" "REDIS_PASSWORD" "secret" $redis.secretName "key" ($redis.passwordKey | default "password")) }}
{{- with $redis.hostKey }}
{{- include "plane.secretKeyEnv" (dict "name" "REDIS_HOST" "secret" $redis.secretName "key" .) }}
{{- end }}
{{- with $redis.portKey }}
{{- include "plane.secretKeyEnv" (dict "name" "REDIS_PORT" "secret" $redis.secretName "key" .) }}
{{- end }}
{{- end }}
{{- end -}}

{{/*
OpenSearch credentials from an externally managed Secret. Kept separate from
plane.infraCredsEnv (which includes it) because Plane AI's workloads need these
without the database/broker/cache parts.

The application reads OPENSEARCH_USERNAME and OPENSEARCH_PASSWORD directly, so there
is no URL to recompose here either. Leaving both unset on AWS makes the API use SigV4
IAM auth instead, which is the better option when the domain supports it.

Caller must indent to the correct depth (env list items).
*/}}
{{- define "plane.opensearchCredsEnv" -}}
{{- $os := .Values.external_secrets.opensearch -}}
{{- if include "plane.externalOpensearch" . }}
{{- include "plane.secretKeyEnv" (dict "name" "OPENSEARCH_USERNAME" "secret" $os.secretName "key" ($os.usernameKey | default "username")) }}
{{- include "plane.secretKeyEnv" (dict "name" "OPENSEARCH_PASSWORD" "secret" $os.secretName "key" ($os.passwordKey | default "password")) }}
{{- end }}
{{- end -}}

{{/*
Infrastructure credentials for silo: Postgres, RabbitMQ and Redis, using the same
env var names as the Django services. Not OpenSearch — silo never queries it.

Caller must indent to the correct depth (env list items).
*/}}
{{- define "plane.siloInfraCredsEnv" -}}
{{- include "plane.postgresCredsEnv" . }}
{{- include "plane.rabbitmqCredsEnv" . }}
{{- include "plane.redisCredsEnv" . }}
{{- include "plane.storageCredsEnv" . }}
{{- end -}}

{{/*
Database credentials for Plane AI, which reads its own env var names rather than
the POSTGRES_* set: PLANE_PI_POSTGRES_* for its own database and
FOLLOWER_POSTGRES_* for its read path into the main Plane database. Both come from
the same external_secrets.database Secret — one managed instance hosting two
databases is the shape the chart provisions. A deployment with genuinely separate
credentials per database should use pi_api_env_existingSecret instead.

Redis is included because Plane AI's Celery broker is Redis in Helm deployments.
RabbitMQ deliberately is NOT: pi resolves an AMQP broker ahead of a Redis one, so
emitting RABBITMQ_* here would silently move its queue off Redis.

Caller must indent to the correct depth (env list items).
*/}}
{{- define "plane.piInfraCredsEnv" -}}
{{- $db := .Values.external_secrets.database -}}
{{- if $db.secretName }}
- name: PLANE_PI_POSTGRES_HOST
  value: {{ include "plane.postgresHost" . | quote }}
- name: PLANE_PI_POSTGRES_PORT
  value: {{ .Values.env.pgdb_port | default "5432" | quote }}
- name: PLANE_PI_POSTGRES_DB
  value: {{ .Values.env.pg_pi_db_name | default "plane_pi" | quote }}
{{- include "plane.secretKeyEnv" (dict "name" "PLANE_PI_POSTGRES_USER" "secret" $db.secretName "key" ($db.usernameKey | default "username")) }}
{{- include "plane.secretKeyEnv" (dict "name" "PLANE_PI_POSTGRES_PASSWORD" "secret" $db.secretName "key" ($db.passwordKey | default "password")) }}
- name: FOLLOWER_POSTGRES_HOST
  value: {{ include "plane.postgresHost" . | quote }}
- name: FOLLOWER_POSTGRES_PORT
  value: {{ .Values.env.pgdb_port | default "5432" | quote }}
- name: FOLLOWER_POSTGRES_DB
  value: {{ .Values.env.pgdb_name | default "plane" | quote }}
{{- include "plane.secretKeyEnv" (dict "name" "FOLLOWER_POSTGRES_USER" "secret" $db.secretName "key" ($db.usernameKey | default "username")) }}
{{- include "plane.secretKeyEnv" (dict "name" "FOLLOWER_POSTGRES_PASSWORD" "secret" $db.secretName "key" ($db.passwordKey | default "password")) }}
{{- with $db.hostKey }}
{{- include "plane.secretKeyEnv" (dict "name" "PLANE_PI_POSTGRES_HOST" "secret" $db.secretName "key" .) }}
{{- include "plane.secretKeyEnv" (dict "name" "FOLLOWER_POSTGRES_HOST" "secret" $db.secretName "key" .) }}
{{- end }}
{{- with $db.portKey }}
{{- include "plane.secretKeyEnv" (dict "name" "PLANE_PI_POSTGRES_PORT" "secret" $db.secretName "key" .) }}
{{- include "plane.secretKeyEnv" (dict "name" "FOLLOWER_POSTGRES_PORT" "secret" $db.secretName "key" .) }}
{{- end }}
{{- end }}
{{- include "plane.redisCredsEnv" . }}
{{- include "plane.opensearchCredsEnv" . }}
{{- include "plane.storageCredsEnv" . }}
{{- end -}}
