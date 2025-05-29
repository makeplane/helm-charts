{{- define "imagePullSecret" }}
{{- printf "{\"auths\":{\"%s\":{\"username\":\"%s\",\"password\":\"%s\"}}}" .Values.dockerRegistry.host .Values.dockerRegistry.loginid .Values.dockerRegistry.password | b64enc }}
{{- end }}

{{- define "enable.hpa" -}}
{{- $metrics := lookup "rbac.authorization.k8s.io/v1" "ClusterRole" "" "system:metrics-server" }}
{{- if not $metrics }}
false
{{- else }}
true
{{- end }}
{{- end }}