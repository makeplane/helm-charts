{{- define "imagePullSecret" }}
{{- printf "{\"auths\":{\"index.docker.io/v1/\":{\"username\":\"%s\",\"password\":\"%s\"}}}" .Values.dockerRegistry.loginid .Values.dockerRegistry.password | b64enc }}
{{- end }}