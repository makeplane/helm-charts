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
Call with the root context, e.g. {{ include "plane.standardLabels" $ }}
*/}}
{{- define "plane.standardLabels" -}}
helm.sh/chart: {{ include "plane.chart" . }}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- with .Chart.AppVersion }}
app.kubernetes.io/version: {{ . | quote }}
{{- end }}
{{- end -}}

{{/*
Object-metadata labels as a bare map (no `labels:` key): the standard recommended
labels merged with the chart-wide user map `.Values.commonLabels`. The user map wins
on key conflicts. Always non-empty (the standard labels are always present), so callers
append it under a `labels:` key without a `with` guard. Call with the root context.
  labels:
    {{- include "plane.resourceLabels" $ | nindent 4 }}
*/}}
{{- define "plane.resourceLabels" -}}
{{- $std := fromYaml (include "plane.standardLabels" .) -}}
{{- toYaml (merge (dict) (.Values.commonLabels | default dict) $std) -}}
{{- end -}}

{{/*
Object-metadata annotations as a bare map (no `annotations:` key): the chart-wide user
map `.Values.commonAnnotations`. May be empty, so callers guard it with `with` and only
then emit the `annotations:` key. Call with the root context.
  {{- with (include "plane.resourceAnnotations" $) }}
  annotations:
    {{- . | nindent 4 }}
  {{- end }}
*/}}
{{- define "plane.resourceAnnotations" -}}
{{- with .Values.commonAnnotations }}{{ toYaml . }}{{- end }}
{{- end -}}

{{/*
Render a resource's `labels` and `annotations` metadata block. Emits the standard
recommended labels + the chart-wide `.Values.commonLabels` + the per-component `labels`
map, all merged into a single block (per-component wins over commonLabels wins over the
standard labels, so no duplicate keys). Annotations merge `.Values.commonAnnotations`
with the per-component `annotations` map (per-component wins) and are emitted only when
non-empty. Never touches spec.selector/matchLabels.
Call with a dict carrying the root context and the component values:
  {{ include "plane.labelsAndAnnotations" (dict "context" $ "values" .Values.services.api) }}
One-shot Jobs that inherit a parent service's values may pass an optional job-override
map whose labels/annotations win over the parent's (e.g. an ArgoCD hook annotation that
belongs on the migration Job but not on the api Deployment):
  {{ include "plane.labelsAndAnnotations" (dict "context" $ "values" .Values.services.api "job" .Values.services.api.migrator) }}
*/}}
{{- define "plane.labelsAndAnnotations" -}}
{{- $std := fromYaml (include "plane.standardLabels" .context) -}}
{{- $job := .job | default dict -}}
{{- $labels := merge (dict) ($job.labels | default dict) (.values.labels | default dict) (.context.Values.commonLabels | default dict) $std -}}
{{- $annotations := merge (dict) ($job.annotations | default dict) (.values.annotations | default dict) (.context.Values.commonAnnotations | default dict) }}
  labels: {{ toYaml $labels | nindent 4 }}
  {{- with $annotations }}
  annotations: {{ toYaml . | nindent 4 }}
  {{- end }}
{{- end }}

{{/*
Pod-template labels as a bare map (no `labels:` key): the standard recommended labels +
chart-wide `.Values.commonLabels` + the per-workload `podLabels` map, merged into one
block (podLabels wins over commonLabels wins over the standard labels). Always non-empty,
so callers append it under the pod template's `labels:` key (which already carries the
static `app.name` selector label) without a `with` guard. The `app.name` label is emitted
by the template itself and never included here, so the selector is never duplicated.
Call with a dict carrying the root context and the component values:
  labels:
    app.name: ...
    {{- include "plane.podLabels" (dict "context" $ "values" .Values.services.api) | nindent 8 }}
*/}}
{{- define "plane.podLabels" -}}
{{- $ctx := .context -}}
{{- $values := .values | default dict -}}
{{- $job := .job | default dict -}}
{{- $std := fromYaml (include "plane.standardLabels" $ctx) -}}
{{- toYaml (merge (dict) ($job.podLabels | default dict) ($values.podLabels | default dict) ($ctx.Values.commonLabels | default dict) $std) -}}
{{- end -}}

{{/*
Pod-template annotations as a bare map (no `annotations:` key): the chart-wide
`.Values.commonAnnotations` merged with the per-workload `podAnnotations` map
(podAnnotations wins). May be empty, so callers guard it with `with`.
Call with a dict carrying the root context and the component values:
  {{- with (include "plane.podAnnotations" (dict "context" $ "values" .Values.services.api)) }}
  {{- . | nindent 8 }}
  {{- end }}
*/}}
{{- define "plane.podAnnotations" -}}
{{- $ctx := .context -}}
{{- $values := .values | default dict -}}
{{- $job := .job | default dict -}}
{{- $merged := merge (dict) ($job.podAnnotations | default dict) ($values.podAnnotations | default dict) ($ctx.Values.commonAnnotations | default dict) -}}
{{- with $merged }}{{ toYaml . }}{{- end }}
{{- end -}}

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
