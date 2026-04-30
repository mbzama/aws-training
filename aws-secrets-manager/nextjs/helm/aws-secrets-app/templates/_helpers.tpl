{{/*
Expand the name of the chart.
*/}}
{{- define "aws-secrets-app.name" -}}
{{- .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Full name: release-chart, truncated to 63 chars.
*/}}
{{- define "aws-secrets-app.fullname" -}}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Service account name.
*/}}
{{- define "aws-secrets-app.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
  {{- default (include "aws-secrets-app.fullname" .) .Values.serviceAccount.name }}
{{- else }}
  {{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Common labels.
*/}}
{{- define "aws-secrets-app.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
app.kubernetes.io/name: {{ include "aws-secrets-app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels.
*/}}
{{- define "aws-secrets-app.selectorLabels" -}}
app.kubernetes.io/name: {{ include "aws-secrets-app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
