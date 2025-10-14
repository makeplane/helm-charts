{{- define "imagePullSecret" }}
{{- printf "{\"auths\":{\"%s\":{\"username\":\"%s\",\"password\":\"%s\"}}}" .Values.dockerRegistry.host .Values.dockerRegistry.loginid .Values.dockerRegistry.password | b64enc }}
{{- end }}

{{- define "plane.labelsAndAnnotations" -}}
  {{- if gt (len .labels) 0 }}
  labels:
    {{- range $key, $value := .labels }}
    {{ $key }}: {{ $value | quote }}
    {{- end }}
  {{- end }}
  {{- if gt (len .annotations) 0 }}
  annotations:
    {{- range $key, $value := .annotations }}
    {{ $key }}: {{ $value | quote }}
    {{- end }}
  {{- end }}
{{- end }}