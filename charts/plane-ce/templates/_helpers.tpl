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
{{/*
Returns "true" when THIS CHART has a TLS Secret to point an ingress at: either
the user supplied one via ssl.tls_secret_name, or cert-manager is set up to mint
one (ssl.generateCerts + ssl.createIssuer, which is what gates
templates/certs/certs.yaml).

Gates the `tls:` blocks and the Traefik entrypoint. Never widen this to cover
externally-terminated TLS -- referencing a Secret that nothing creates is the
bug this helper exists to stop: Traefik answers such a handshake with its
built-in self-signed certificate and logs nothing.
*/}}
{{- define "plane.chartManagedCert" -}}
  {{- if or .Values.ssl.tls_secret_name (and .Values.ssl.generateCerts .Values.ssl.createIssuer) -}}
    true
  {{- end -}}
{{- end -}}

{{/*
Returns "true" when users reach Plane over https://, whoever terminates it.

That is either a chart-managed certificate, or ssl.externalTermination for TLS
handled in front of Plane -- a cloud load balancer, Cloudflare, a service mesh,
or a Traefik entrypoint with its own certificate (`websecure.http.tls=true`).
The chart owns no Secret in that second case, so this must NOT be used to emit a
`tls:` block; use plane.chartManagedCert for that.

Drives ONLY the scheme of the self-referential URLs handed to the app (WEB_URL).

Deliberately NOT the Traefik entrypoint. "Users are on https" says nothing about
which entrypoint traffic arrives on: an upstream terminator (ALB, NLB TLS
listener, Cloudflare) forwards cleartext, which lands on `web`, while a Traefik
entrypoint carrying its own certificate lands on `websecure`. Those need
opposite entrypoints from the same value, so the entrypoint derives from
plane.chartManagedCert instead and ingress.traefik.entryPoints overrides it.
*/}}
{{- define "plane.tlsEnabled" -}}
  {{- if or (eq (include "plane.chartManagedCert" .) "true") .Values.ssl.externalTermination -}}
    true
  {{- end -}}
{{- end -}}

{{/*
Traefik entrypoint names for the IngressRoutes.

Honours an explicit ingress.traefik.entryPoints override (some clusters rename
the defaults, and it is the way to select `websecure` when Traefik's own
entrypoint terminates TLS); otherwise derives them from whether THIS CHART
terminates TLS, so an install with SSL left off is reachable over plain HTTP
instead of serving Traefik's fallback self-signed certificate.

Keyed on plane.chartManagedCert, NOT plane.tlsEnabled: with TLS terminated
upstream the chart must still bind `web`, because the terminator forwards
cleartext and a route attached only to `websecure` would never match it.

An empty value is the "derive it" sentinel, never a literal empty list -- the
CRD requires at least one entrypoint. A bare string is accepted and wrapped into
a single-item list, since `--set ingress.traefik.entryPoints=websecure` yields a
scalar and would otherwise render a list-less mapping the CRD rejects.
Caller must nindent to the correct depth.
*/}}
{{- define "plane.traefikEntryPoints" -}}
  {{- with .Values.ingress.traefik.entryPoints -}}
    {{- if kindIs "string" . -}}
      {{- toYaml (list .) -}}
    {{- else -}}
      {{- toYaml . -}}
    {{- end -}}
  {{- else -}}
    {{- if eq (include "plane.chartManagedCert" $) "true" -}}
- websecure
    {{- else -}}
- web
    {{- end -}}
  {{- end -}}
{{- end -}}
