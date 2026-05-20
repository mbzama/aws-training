{{/*
Expand the name of the chart.
*/}}
{{- define "lambda-authorizer.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
Truncate at 63 chars because some Kubernetes name fields are limited to this.
*/}}
{{- define "lambda-authorizer.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Chart label (name + version).
*/}}
{{- define "lambda-authorizer.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels applied to all resources.
*/}}
{{- define "lambda-authorizer.labels" -}}
helm.sh/chart: {{ include "lambda-authorizer.chart" . }}
{{ include "lambda-authorizer.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels.
*/}}
{{- define "lambda-authorizer.selectorLabels" -}}
app.kubernetes.io/name: {{ include "lambda-authorizer.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Service account name.
*/}}
{{- define "lambda-authorizer.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "lambda-authorizer.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Deploy Job name — includes the chart version so a new Job is created
on every helm upgrade (Kubernetes Jobs are immutable once created).
*/}}
{{- define "lambda-authorizer.jobName" -}}
{{- printf "%s-deploy-%s" (include "lambda-authorizer.fullname" .) (.Chart.AppVersion | replace "." "-") | trunc 63 | trimSuffix "-" }}
{{- end }}
