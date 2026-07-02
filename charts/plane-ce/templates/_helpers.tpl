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