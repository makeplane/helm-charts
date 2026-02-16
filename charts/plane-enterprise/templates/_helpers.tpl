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

{{- define "plane.prometheusAnnotations" -}}
{{- if and .root.Values.monitoring .root.Values.monitoring.enabled -}}
prometheus.io/scrape: {{ .root.Values.monitoring.prometheus.scrape | quote }}
prometheus.io/port: {{ .port | quote }}
prometheus.io/path: {{ .root.Values.monitoring.prometheus.path | quote }}
prometheus.io/scheme: {{ .root.Values.monitoring.prometheus.scheme | quote }}
{{- end }}
{{- end }}
