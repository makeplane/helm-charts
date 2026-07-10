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
Returns "true" when at least one custom CA secret is configured, in either the
top-level `customCA` section or the legacy `airgapped` keys. This is decoupled
from `airgapped.enabled` so custom CA certs can be mounted in non-airgapped
deployments (e.g. an S3-compatible endpoint that uses a private CA).
*/}}
{{- define "plane.s3CAEnabled" -}}
  {{- if or (gt (len .Values.customCA.s3Secrets) 0) (and .Values.customCA.s3SecretName .Values.customCA.s3SecretKey) (gt (len .Values.airgapped.s3Secrets) 0) (and .Values.airgapped.s3SecretName .Values.airgapped.s3SecretKey) -}}
    true
  {{- end -}}
{{- end -}}

{{/*
Resolve the effective list of CA secrets and render them as projected-volume sources.
Precedence: customCA.s3Secrets > customCA single secret > airgapped.s3Secrets > airgapped single secret.
Single-secret (legacy) configs are normalized into the same { name, key } shape.
Output starts at column 0; caller controls indentation (e.g. nindent).
*/}}
{{- define "plane.s3CAProjectedSources" -}}
{{- $secrets := list -}}
{{- if gt (len .Values.customCA.s3Secrets) 0 -}}
  {{- $secrets = .Values.customCA.s3Secrets -}}
{{- else if and .Values.customCA.s3SecretName .Values.customCA.s3SecretKey -}}
  {{- $secrets = list (dict "name" .Values.customCA.s3SecretName "key" .Values.customCA.s3SecretKey) -}}
{{- else if gt (len .Values.airgapped.s3Secrets) 0 -}}
  {{- $secrets = .Values.airgapped.s3Secrets -}}
{{- else if and .Values.airgapped.s3SecretName .Values.airgapped.s3SecretKey -}}
  {{- $secrets = list (dict "name" .Values.airgapped.s3SecretName "key" .Values.airgapped.s3SecretKey) -}}
{{- end -}}
{{- range $secrets }}
- secret:
    name: {{ .name }}
    items:
      - key: {{ .key }}
        path: {{ .key }}
{{- end }}
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
        {{- include "plane.s3CAProjectedSources" . | trim | nindent 8 }}
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
        {{- include "plane.s3CAProjectedSources" . | trim | nindent 8 }}
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
