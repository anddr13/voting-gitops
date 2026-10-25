{{- define "voting.selectorLabels" -}}
app.kubernetes.io/name: {{ . }}
app.kubernetes.io/part-of: voting
{{- end }}

{{- define "voting.labels" -}}
{{ include "voting.selectorLabels" .name }}
app.kubernetes.io/version: {{ .root.Values.image.tag | trunc 63 | quote }}
helm.sh/chart: {{ printf "%s-%s" .root.Chart.Name .root.Chart.Version }}
{{- end }}

{{/*
kafka.brokers with every short host name qualified as <host>.<release namespace>.svc.
The app pods resolve short names in their own namespace; the KEDA operator runs in another one.
*/}}
{{- define "voting.kafkaBrokersFQDN" -}}
{{- $brokers := list -}}
{{- range splitList "," .Values.kafka.brokers -}}
{{- $parts := splitList ":" (trim .) -}}
{{- $host := first $parts -}}
{{- if not (contains "." $host) -}}
{{- $host = printf "%s.%s.svc" $host $.Release.Namespace -}}
{{- end -}}
{{- $brokers = append $brokers (printf "%s:%s" $host (last $parts)) -}}
{{- end -}}
{{- join "," $brokers -}}
{{- end }}
