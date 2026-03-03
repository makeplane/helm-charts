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
Normalize the deprecated s3SecretName/s3SecretKey into the s3Secrets list format.
Returns "true" when airgapped is enabled and at least one CA secret is configured.
*/}}
{{- define "plane.s3CaEnabled" -}}
  {{- if .Values.airgapped.enabled -}}
    {{- if gt (len .Values.airgapped.s3Secrets) 0 -}}
      true
    {{- else if and .Values.airgapped.s3SecretName .Values.airgapped.s3SecretKey -}}
      true
    {{- end -}}
  {{- end -}}
{{- end -}}

{{/*
Render the volumes block for custom S3 CA certificates.
Always uses a projected volume so both single-secret (legacy) and multi-secret configs
produce the same volume structure.
Caller must nindent to the correct depth.
*/}}
{{- define "plane.s3CaVolumes" -}}
{{- if include "plane.s3CaEnabled" . -}}
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
{{- define "plane.s3CaVolumeMounts" -}}
{{- if include "plane.s3CaEnabled" . -}}
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
{{- define "plane.s3CaInitScript" -}}
{{- if include "plane.s3CaEnabled" . -}}
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
{{- define "plane.s3CaEnvVars" -}}
{{- if include "plane.s3CaEnabled" . -}}
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
{{- define "plane.s3CaNodeVolumes" -}}
{{- if include "plane.s3CaEnabled" . -}}
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
{{- define "plane.s3CaNodeBundleMount" -}}
{{- if include "plane.s3CaEnabled" . -}}
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
{{- define "plane.s3CaNodeEnvVars" -}}
{{- if include "plane.s3CaEnabled" . -}}
- name: NODE_EXTRA_CA_CERTS
  value: "/ca-bundle/custom-ca-bundle.crt"
{{- end }}
{{- end -}}
