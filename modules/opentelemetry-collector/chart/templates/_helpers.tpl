{{- define "togglemaster-otel.labels" -}}
app.kubernetes.io/name: opentelemetry-collector
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/part-of: togglemaster
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "togglemaster-otel.selectorLabels" -}}
app.kubernetes.io/name: opentelemetry-collector
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
