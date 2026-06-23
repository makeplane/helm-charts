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

{{- define "plane.labelsAndAnnotations" -}}
  {{- with .labels }}
  labels: {{ toYaml . | nindent 4 }}
  {{- end }}
  {{- with .annotations }}
  annotations: {{ toYaml . | nindent 4 }}
  {{- end }}
{{- end }}

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
Selects which ingress template renders, decoupling the controller *type* (which
resource kind to emit) from the ingress *class name* (a free-form string).

Returns one of:
  - "traefik" -> templates/ingress-traefik.yaml emits a traefik.io/v1alpha1 IngressRoute
  - "ingress" -> templates/ingress.yaml emits a networking.k8s.io/v1 Ingress
                 (nginx, F5 NGINX, HAProxy, or any other standard controller)

Resolution order:
  1. If ingress.controller is set explicitly, it wins. Only the literal value
     "traefik" selects the IngressRoute path; any other value (e.g. "nginx",
     "f5", "haproxy") selects the standard Ingress path. This lets atypical
     class names like "nginx-new" be used without affecting template selection.
  2. Otherwise (legacy behavior) the choice is inferred from ingress.ingressClass:
     a value starting with "traefik" selects Traefik, anything else selects the
     standard Ingress. Set ingress.controller to override the inference (e.g. a
     standard Ingress whose ingressClassName happens to start with "traefik").
*/}}
{{- define "plane.ingressController" -}}
  {{- $c := .Values.ingress.controller | default "" | lower | trim -}}
  {{- if $c -}}
    {{- if eq $c "traefik" -}}traefik{{- else -}}ingress{{- end -}}
  {{- else if hasPrefix "traefik" (.Values.ingress.ingressClass | default "" | lower) -}}
    traefik
  {{- else -}}
    ingress
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
