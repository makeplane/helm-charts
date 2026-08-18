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
  {{- with .values.annotations }}
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
OpenTelemetry — returns "true" when observability.otel.enabled is set, else "".
*/}}
{{- define "plane.otel.enabled" -}}
{{- if and .Values.observability .Values.observability.otel .Values.observability.otel.enabled -}}true{{- end -}}
{{- end -}}

{{/*
Returns "true" when the OTLP exporter headers are sourced from a Secret — either
because observability.otel.headers is set (chart-managed Secret) or because an
existing Secret was supplied. Empty otherwise, so no secretRef is emitted for a
deployment that needs no ingestion credentials.
*/}}
{{- define "plane.otel.secretEnabled" -}}
{{- if eq (include "plane.otel.enabled" .) "true" -}}
{{- if or .Values.observability.otel.headers .Values.external_secrets.otel_env_existingSecret -}}true{{- end -}}
{{- end -}}
{{- end -}}

{{/*
envFrom entries for the shared OTEL ConfigMap (+ the OTLP headers Secret, when
one is in play). Call with the root context and nindent to the envFrom list
depth, e.g.
  {{- include "plane.otel.envFrom" $ | nindent 10 }}
*/}}
{{- define "plane.otel.envFrom" -}}
{{- if eq (include "plane.otel.enabled" .) "true" -}}
- configMapRef:
    name: {{ .Release.Name }}-otel-vars
    optional: false
{{- if eq (include "plane.otel.secretEnabled" .) "true" }}
- secretRef:
    name: {{ if not (empty .Values.external_secrets.otel_env_existingSecret) }}{{ .Values.external_secrets.otel_env_existingSecret }}{{ else }}{{ .Release.Name }}-otel-secrets{{ end }}
    optional: false
{{- end }}
{{- end -}}
{{- end -}}

{{/*
Per-workload OTEL_SERVICE_NAME (overrides the shared ConfigMap so each workload
reports its own service.name). Call with a dict and nindent, e.g.
  {{- include "plane.otel.serviceEnv" (dict "ctx" $ "service" "api") | nindent 10 }}
*/}}
{{- define "plane.otel.serviceEnv" -}}
{{- if eq (include "plane.otel.enabled" .ctx) "true" -}}
- name: OTEL_SERVICE_NAME
  value: {{ .service | quote }}
{{- end -}}
{{- end -}}

{{/*
Returns "true" when the chart has an actual TLS certificate to serve: either the
user pointed at their own Secret via ssl.tls_secret_name, or cert-manager is set
up to mint one (ssl.generateCerts + ssl.createIssuer, which is what gates
templates/certs/certs.yaml).

This is the same condition templates/ingress.yaml uses to decide whether to emit
a `tls:` block, factored out so the Traefik path stays in step with it. Without
it, ingress-traefik.yaml would advertise a Secret that nothing ever creates.
*/}}
{{- define "plane.tlsEnabled" -}}
  {{- if or .Values.ssl.tls_secret_name (and .Values.ssl.generateCerts .Values.ssl.createIssuer) -}}
    true
  {{- end -}}
{{- end -}}

{{/*
Traefik entrypoint names for the IngressRoute.

Honours an explicit ingress.traefik.entryPoints override (some clusters rename
the defaults); otherwise derives them from whether TLS is configured, so an
install with SSL left off is reachable over plain HTTP instead of serving
Traefik's fallback self-signed certificate.
Caller must nindent to the correct depth.
*/}}
{{- define "plane.traefikEntryPoints" -}}
  {{- with .Values.ingress.traefik.entryPoints -}}
    {{- toYaml . -}}
  {{- else -}}
    {{- if eq (include "plane.tlsEnabled" .) "true" -}}
- websecure
    {{- else -}}
- web
    {{- end -}}
  {{- end -}}
{{- end -}}
