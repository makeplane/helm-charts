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

{{- define "plane.labelsAndAnnotations" -}}
  {{- with .labels }}
  labels: {{ toYaml . | nindent 4 }}
  {{- end }}
  {{- with .annotations }}
  annotations: {{ toYaml . | nindent 4 }}
  {{- end }}
{{- end }}

{{/*
plane.metrics.installationUUID returns a stable installation UUID.
This template ensures the same UUID is used across ALL template invocations
within a single Helm render by caching the value.

Priority:
  1. Explicitly provided .Values.metrics.installation.uuid
  2. Existing UUID from the installation-uuid Secret (survives upgrades)
  3. Newly generated UUID (cached for this render, stored in Secret for persistence)

IMPORTANT: Workloads should prefer using secretKeyRef to read from the
{{ .Release.Name }}-installation-uuid Secret for environment variables.
This template is for use in ConfigMaps and other non-secret resources.
*/}}
{{- define "plane.metrics.installationUUID" -}}
{{- if .Values.metrics.installation.uuid -}}
{{- .Values.metrics.installation.uuid -}}
{{- else -}}
{{- $secretName := printf "%s-installation-uuid" .Release.Name -}}
{{- $existingSecret := lookup "v1" "Secret" .Release.Namespace $secretName -}}
{{- if and $existingSecret $existingSecret.data (index $existingSecret.data "uuid") -}}
{{- index $existingSecret.data "uuid" | b64dec -}}
{{- else -}}
{{- /* Fresh install: generate deterministic UUID from release info */ -}}
{{- /* This ensures consistency across all template invocations */ -}}
{{- $hash := printf "%s-%s-%s" .Release.Name .Release.Namespace .Chart.Name | sha256sum | trunc 32 -}}
{{- printf "%s-%s-%s-%s-%s" (substr 0 8 $hash) (substr 8 12 $hash) (substr 12 16 $hash) (substr 16 20 $hash) (substr 20 32 $hash) -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
plane.metrics.installationUUIDSecretName returns the name of the Secret
containing the installation UUID. Use this for secretKeyRef in pod specs.
*/}}
{{- define "plane.metrics.installationUUIDSecretName" -}}
{{- printf "%s-installation-uuid" .Release.Name -}}
{{- end -}}
