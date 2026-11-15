{{- define "plane-mcp-server.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "plane-mcp-server.commonLabels" -}}
helm.sh/chart: {{ include "plane-mcp-server.chart" . }}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- with .Chart.AppVersion }}
app.kubernetes.io/version: {{ . | quote }}
{{- end }}
{{- end -}}

{{- define "plane-mcp-server.labelsAndAnnotations" }}
  labels:
    {{- include "plane-mcp-server.commonLabels" .context | nindent 4 }}
    {{- with .values.labels }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
  {{- with .values.annotations }}
  annotations: {{ toYaml . | nindent 4 }}
  {{- end }}
{{- end }}

{{- define "plane-mcp-server.podScheduling" -}}
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
Pod-template annotations that decide when `helm upgrade` restarts a workload.

  checksum/config  sha256 of the rendered config templates this workload reads, so a change to
                   them restarts it and an upgrade that changes nothing it reads does not.
  timestamp        a new value on every render, restarting the workload on every upgrade.
                   Rendered when rolloutOnUpgrade is "always", or "auto" with an image tag that is
                   not a release version -- see rolloutOnUpgrade in values.yaml.

The call site owns the `annotations:` key, so a workload with nothing to annotate renders none:

  {{- with include "plane-mcp-server.rolloutAnnotations" (dict "ctx" $ "tag" <image tag> "configs" (list "config-secrets/<file>.yaml")) }}
      annotations:
        {{- . | nindent 8 }}
      {{- end }}
*/}}
{{- define "plane-mcp-server.rolloutAnnotations" -}}
{{- $ctx := .ctx -}}
{{- $mode := toString ($ctx.Values.rolloutOnUpgrade | default "auto") -}}
{{- if not (has $mode (list "auto" "always" "never")) -}}
{{- fail (printf "rolloutOnUpgrade is %q; it must be auto, always or never." $mode) -}}
{{- end -}}
{{- $sums := list -}}
{{- range .configs -}}
{{- $sums = append $sums (include (print $ctx.Template.BasePath "/" .) $ctx | sha256sum) -}}
{{- end -}}
{{- $out := list -}}
{{- if $sums -}}
{{- $out = append $out (printf "checksum/config: %s" (join "," $sums | sha256sum | quote)) -}}
{{- end -}}
{{- if or (eq $mode "always") (and (eq $mode "auto") (not (regexMatch "^v?[0-9]+\\.[0-9]+" (toString .tag)))) -}}
{{- $out = append $out (printf "timestamp: %s" (now | quote)) -}}
{{- end -}}
{{- join "\n" $out -}}
{{- end -}}
