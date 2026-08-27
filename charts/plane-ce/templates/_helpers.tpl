{{- define "imagePullSecret" }}
{{- printf "{\"auths\":{\"%s\":{\"username\":\"%s\",\"password\":\"%s\"}}}" .Values.dockerRegistry.host .Values.dockerRegistry.loginid .Values.dockerRegistry.password | b64enc }}
{{- end }}

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
  {{ include "plane.labelsAndAnnotations" (dict "context" $ "values" .Values.api) }}
*/}}
{{- define "plane.labelsAndAnnotations" }}
  labels:
    {{- include "plane.commonLabels" .context | nindent 4 }}
    {{- with .values.labels }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
  {{- with .values.annotations }}
  annotations: {{ toYaml . | nindent 4 }}
  {{- end }}
{{- end }}
{{/*
Returns "true" when THIS CHART has a TLS Secret to point an ingress at: either
the user supplied one via ssl.tls_secret_name, or cert-manager is set up to mint
one (ssl.generateCerts + ssl.createIssuer, which is what gates
templates/certs/certs.yaml).

Gates the `tls:` blocks and the Traefik entrypoint. Never widen this to cover
externally-terminated TLS -- referencing a Secret that nothing creates is the
bug this helper exists to stop: Traefik answers such a handshake with its
built-in self-signed certificate and logs nothing.
*/}}
{{- define "plane.chartManagedCert" -}}
  {{- if or .Values.ssl.tls_secret_name (and .Values.ssl.generateCerts .Values.ssl.createIssuer) -}}
    true
  {{- end -}}
{{- end -}}

{{/*
Returns "true" when users reach Plane over https://, whoever terminates it.

That is either a chart-managed certificate, or ssl.externalTermination for TLS
handled in front of Plane -- a cloud load balancer, Cloudflare, a service mesh,
or a Traefik entrypoint with its own certificate (`websecure.http.tls=true`).
The chart owns no Secret in that second case, so this must NOT be used to emit a
`tls:` block; use plane.chartManagedCert for that.

Drives ONLY the scheme of the self-referential URLs handed to the app (WEB_URL).

Deliberately NOT the Traefik entrypoint. "Users are on https" says nothing about
which entrypoint traffic arrives on: an upstream terminator (ALB, NLB TLS
listener, Cloudflare) forwards cleartext, which lands on `web`, while a Traefik
entrypoint carrying its own certificate lands on `websecure`. Those need
opposite entrypoints from the same value, so the entrypoint derives from
plane.chartManagedCert instead and ingress.traefik.entryPoints overrides it.
*/}}
{{- define "plane.tlsEnabled" -}}
  {{- if or (eq (include "plane.chartManagedCert" .) "true") .Values.ssl.externalTermination -}}
    true
  {{- end -}}
{{- end -}}

{{/*
Traefik entrypoint names for the IngressRoutes.

Honours an explicit ingress.traefik.entryPoints override (some clusters rename
the defaults, and it is the way to select `websecure` when Traefik's own
entrypoint terminates TLS); otherwise derives them from whether THIS CHART
terminates TLS, so an install with SSL left off is reachable over plain HTTP
instead of serving Traefik's fallback self-signed certificate.

Keyed on plane.chartManagedCert, NOT plane.tlsEnabled: with TLS terminated
upstream the chart must still bind `web`, because the terminator forwards
cleartext and a route attached only to `websecure` would never match it.

An empty value is the "derive it" sentinel, never a literal empty list -- the
CRD requires at least one entrypoint. A bare string is accepted and wrapped into
a single-item list, since `--set ingress.traefik.entryPoints=websecure` yields a
scalar and would otherwise render a list-less mapping the CRD rejects.
Caller must nindent to the correct depth.
*/}}
{{- define "plane.traefikEntryPoints" -}}
  {{- with .Values.ingress.traefik.entryPoints -}}
    {{- if kindIs "string" . -}}
      {{- toYaml (list .) -}}
    {{- else -}}
      {{- toYaml . -}}
    {{- end -}}
  {{- else -}}
    {{- if eq (include "plane.chartManagedCert" $) "true" -}}
- websecure
    {{- else -}}
- web
    {{- end -}}
  {{- end -}}
{{- end -}}

{{/*
================================================================================
ServiceAccount and cloud identity
================================================================================
*/}}

{{/*
Name of the ServiceAccount every workload runs as. Defaults to the release-scoped
account the chart creates; override to run as one you manage yourself (created by
Terraform or Crossplane, already bound to a cloud IAM role, or the target of an EKS Pod
Identity association).
*/}}
{{- define "plane.serviceAccountName" -}}
{{- .Values.serviceAccount.name | default (printf "%s-srv-account" .Release.Name) -}}
{{- end -}}

{{/*
Returns "true" when the chart should render the ServiceAccount itself. Skipped when it
is managed outside the chart and only referenced here.
*/}}
{{- define "plane.createServiceAccount" -}}
{{- if .Values.serviceAccount.create -}}
true
{{- end -}}
{{- end -}}

{{/*
Pod-template labels some workload-identity implementations require — Azure Workload
Identity needs azure.workload.identity/use on the pod. Indentation is baked in for the
pod-template label position, so call it bare.
*/}}
{{- define "plane.serviceAccountPodLabels" -}}
{{- with .Values.serviceAccount.podLabels }}
{{- toYaml . | nindent 8 }}
{{- end }}
{{- end -}}

{{/*
================================================================================
Externalized secrets
================================================================================
*/}}

{{/*
Resolve a secret value with an optional insecure fallback.

Returns .value when set; otherwise fails the render when env.requireExplicitSecrets is
true, and falls back when it is false (the historical behaviour, kept so existing
installs keep working). The fallbacks this chart ships are PUBLIC CONSTANTS — any real
install must supply its own.

Call with: (dict "context" $ "name" "env.secret_key" "value" .Values.env.secret_key "fallback" "...")
*/}}
{{- define "plane.secretValue" -}}
{{- if .value -}}
{{- .value -}}
{{- else if .context.Values.env.requireExplicitSecrets -}}
{{- required (printf "%s has no value. Set it in values.yaml, supply it through external_secrets.app_keys_existingSecret, or set env.requireExplicitSecrets=false to fall back to the chart's insecure default." .name) nil -}}
{{- else -}}
{{- .fallback -}}
{{- end -}}
{{- end -}}

{{/*
envFrom entry for the Secret carrying the shared signing keys (SECRET_KEY,
LIVE_SERVER_SECRET_KEY). Renders nothing unless
external_secrets.app_keys_existingSecret is set.

These keys are duplicated across the app and live Secrets and must agree for the two to
talk to each other, so pointing both at one Secret makes that agreement structural.
While it is set the chart emits neither key itself.

SECRET_KEY additionally derives the key that encrypts the instance-configuration rows,
so it must never be rotated on a running instance.

Indentation is baked in for the container envFrom position, so call it bare.
*/}}
{{- define "plane.appKeysSecretRef" -}}
{{- with .Values.external_secrets.app_keys_existingSecret }}
          - secretRef:
              name: {{ . }}
              optional: false
{{- end }}
{{- end -}}

{{/*
Returns "true" when object-storage credentials come from an externally managed Secret.
Never true while the bundled MinIO is deployed, which supplies its own.
*/}}
{{- define "plane.externalStorage" -}}
{{- if and .Values.external_secrets.storage.secretName (not .Values.minio.local_setup) -}}
true
{{- end -}}
{{- end -}}

{{/*
Emit one env entry sourced from a key inside an externally managed Secret.
Emits a leading newline so call sites can use a left-trim marker without swallowing the
separator from the previous entry.
*/}}
{{- define "plane.secretKeyEnv" }}
- name: {{ .name }}
  valueFrom:
    secretKeyRef:
      name: {{ .secret }}
      key: {{ .key }}
{{- end -}}

{{/*
Object-storage credentials as explicit env entries, which win over envFrom.

On a cloud, prefer a pod identity and leave this unset: with env.aws_access_key empty
the chart omits those variables entirely, which is what lets the SDK credential chain
reach the pod's role. Use this for an S3-compatible backend with no workload identity.

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
{{- end }}
{{- end -}}
