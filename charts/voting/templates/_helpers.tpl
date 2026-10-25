{{- define "voting.selectorLabels" -}}
app.kubernetes.io/name: {{ . }}
app.kubernetes.io/part-of: voting
{{- end }}

{{- define "voting.labels" -}}
{{ include "voting.selectorLabels" .name }}
app.kubernetes.io/version: {{ .root.Values.image.tag | trunc 63 | quote }}
helm.sh/chart: {{ printf "%s-%s" .root.Chart.Name .root.Chart.Version }}
{{- end }}
