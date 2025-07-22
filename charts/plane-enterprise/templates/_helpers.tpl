{{- define "imagePullSecret" }}
{{- printf "{\"auths\":{\"%s\":{\"username\":\"%s\",\"password\":\"%s\"}}}" .Values.dockerRegistry.registry .Values.dockerRegistry.loginid .Values.dockerRegistry.password | b64enc }}
{{- end }}

{{- define "hashString" -}}
{{- printf "%s%s%s%s" .Values.license.licenseServer .Values.license.licenseDomain .Release.Namespace .Release.Name | sha256sum  -}}
{{- end -}}

{{- define "enable.hpa" -}}
{{- $metrics := lookup "rbac.authorization.k8s.io/v1" "ClusterRole" "" "system:metrics-server" }}
{{- if not $metrics }}
false
{{- else }}
true
{{- end }}
{{- end }}
