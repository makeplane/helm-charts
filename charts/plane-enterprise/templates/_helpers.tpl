{{- define "imagePullSecret" }}
{{- printf "{\"auths\":{\"%s\":{\"username\":\"%s\",\"password\":\"%s\"}}}" .Values.dockerRegistry.registry .Values.dockerRegistry.loginid .Values.dockerRegistry.password | b64enc }}
{{- end }}

{{- define "hashString" -}}
{{- printf "%s%s%s%s" .Values.license.licenseServer .Values.license.licenseDomain .Release.Namespace .Release.Name | sha256sum  -}}
{{- end -}}

{{- define "doc-store-secret" -}}
{{- default (printf "%s-doc-store-secrets" .Release.Name) .Values.services.minio.existingSecret -}}
{{- end -}}

{{- define "app-secret" -}}
{{- default (printf "%s-app-secrets" .Release.Name) .Values.env.existingSecret -}}
{{- end -}}
