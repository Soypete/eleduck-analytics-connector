{{/*
Expand the name of the chart.
*/}}
{{- define "podcast-scraper.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "podcast-scraper.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "podcast-metrics-scraper" | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "podcast-scraper.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "podcast-scraper.labels" -}}
helm.sh/chart: {{ include "podcast-scraper.chart" . }}
{{ include "podcast-scraper.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/component: scraper
app.kubernetes.io/part-of: eleduck-analytics-stack
{{- end }}

{{/*
Selector labels
*/}}
{{- define "podcast-scraper.selectorLabels" -}}
app: podcast-scraper
app.kubernetes.io/name: {{ include "podcast-scraper.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
