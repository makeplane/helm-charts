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
Call with the root context, e.g. {{ include "plane.standardLabels" $ }}
*/}}
{{- define "plane.standardLabels" -}}
helm.sh/chart: {{ include "plane.chart" . }}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- with .Chart.AppVersion }}
app.kubernetes.io/version: {{ . | quote }}
{{- end }}
{{- end -}}

{{/*
Object-metadata labels as a bare map (no `labels:` key): the standard recommended
labels merged with the chart-wide user map `.Values.commonLabels`. The user map wins
on key conflicts. Always non-empty (the standard labels are always present), so callers
append it under a `labels:` key without a `with` guard. Call with the root context.
  labels:
    {{- include "plane.resourceLabels" $ | nindent 4 }}
*/}}
{{- define "plane.resourceLabels" -}}
{{- $std := fromYaml (include "plane.standardLabels" .) -}}
{{- toYaml (merge (dict) (.Values.commonLabels | default dict) $std) -}}
{{- end -}}

{{/*
Object-metadata annotations as a bare map (no `annotations:` key): the chart-wide user
map `.Values.commonAnnotations`. May be empty, so callers guard it with `with` and only
then emit the `annotations:` key. Call with the root context.
  {{- with (include "plane.resourceAnnotations" $) }}
  annotations:
    {{- . | nindent 4 }}
  {{- end }}
*/}}
{{- define "plane.resourceAnnotations" -}}
{{- with .Values.commonAnnotations }}{{ toYaml . }}{{- end }}
{{- end -}}

{{/*
Render a resource's `labels` and `annotations` metadata block. Emits the standard
recommended labels + the chart-wide `.Values.commonLabels` + the per-component `labels`
map, all merged into a single block (per-component wins over commonLabels wins over the
standard labels, so no duplicate keys). Annotations merge `.Values.commonAnnotations`
with the per-component `annotations` map (per-component wins) and are emitted only when
non-empty. Never touches spec.selector/matchLabels.
Call with a dict carrying the root context and the component values:
  {{ include "plane.labelsAndAnnotations" (dict "context" $ "values" .Values.api) }}
One-shot Jobs that inherit a parent component's values may pass an optional job-override
map whose labels/annotations win over the parent's (e.g. an ArgoCD hook annotation that
belongs on the migration Job but not on the api Deployment):
  {{ include "plane.labelsAndAnnotations" (dict "context" $ "values" .Values.api "job" .Values.api.migrator) }}
*/}}
{{- define "plane.labelsAndAnnotations" -}}
{{- $std := fromYaml (include "plane.standardLabels" .context) -}}
{{- $job := .job | default dict -}}
{{- $labels := merge (dict) ($job.labels | default dict) (.values.labels | default dict) (.context.Values.commonLabels | default dict) $std -}}
{{- $annotations := merge (dict) ($job.annotations | default dict) (.values.annotations | default dict) (.context.Values.commonAnnotations | default dict) }}
  labels: {{ toYaml $labels | nindent 4 }}
  {{- with $annotations }}
  annotations: {{ toYaml . | nindent 4 }}
  {{- end }}
{{- end }}

{{/*
Pod-template labels as a bare map (no `labels:` key): the standard recommended labels +
chart-wide `.Values.commonLabels` + the per-workload `podLabels` map, merged into one
block (podLabels wins over commonLabels wins over the standard labels). Always non-empty,
so callers append it under the pod template's `labels:` key (which already carries the
static `app.name` selector label) without a `with` guard. The `app.name` label is emitted
by the template itself and never included here, so the selector is never duplicated.
Optional "job" map adds a one-shot Job's podLabels override tier (wins over all).
Call with a dict carrying the root context and the component values:
  labels:
    app.name: ...
    {{- include "plane.podLabels" (dict "context" $ "values" .Values.api) | nindent 8 }}
*/}}
{{- define "plane.podLabels" -}}
{{- $ctx := .context -}}
{{- $values := .values | default dict -}}
{{- $job := .job | default dict -}}
{{- $std := fromYaml (include "plane.standardLabels" $ctx) -}}
{{- toYaml (merge (dict) ($job.podLabels | default dict) ($values.podLabels | default dict) ($ctx.Values.commonLabels | default dict) $std) -}}
{{- end -}}

{{/*
Pod-template annotations as a bare map (no `annotations:` key): the chart-wide
`.Values.commonAnnotations` merged with the per-workload `podAnnotations` map
(podAnnotations wins; an optional "job" map's podAnnotations win over both).
May be empty, so callers guard it with `with`.
Call with a dict carrying the root context and the component values:
  {{- with (include "plane.podAnnotations" (dict "context" $ "values" .Values.api)) }}
  {{- . | nindent 8 }}
  {{- end }}
*/}}
{{- define "plane.podAnnotations" -}}
{{- $ctx := .context -}}
{{- $values := .values | default dict -}}
{{- $job := .job | default dict -}}
{{- $merged := merge (dict) ($job.podAnnotations | default dict) ($values.podAnnotations | default dict) ($ctx.Values.commonAnnotations | default dict) -}}
{{- with $merged }}{{ toYaml . }}{{- end }}
{{- end -}}