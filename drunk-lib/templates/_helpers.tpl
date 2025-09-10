# Template: _helpers.tpl
# Author: Duy Bao (baoduy)
# Repository: https://github.com/baoduy/drunk.charts
# Description: Helm template library for drunk.charts
# Created: 2025-09-10

# Get the mapped service port for ingress
# If deployment has only 1 port, map to 80. If more than 1, map to the first port in the map.
# Usage: {{ include "drunk.utils.ingressPort" . }}
{{- define "drunk.utils.ingressPort" -}}
{{- if and .Values.deployment .Values.deployment.ports -}}
	{{- $ports := .Values.deployment.ports -}}
	{{- if eq (len $ports) 1 -}}
		80
	{{- else -}}
		{{- $firstPort := (keys $ports | first) -}}
		{{- get $ports $firstPort -}}
	{{- end -}}
{{- else -}}
	8080
{{- end -}}
{{- end -}}
# Expand the name of the chart.
{{- define "app.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

# Create a default fully qualified app name.
# We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
# If release name contains chart name it will be used as a full name.
{{- define "app.fullname" -}}
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

# Create chart name and version as used by the chart label.
{{- define "app.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

# Common labels
{{- define "app.labels" -}}
helm.sh/chart: {{ include "app.chart" . }}
{{ include "app.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

# Selector labels
{{- define "app.selectorLabels" -}}
app.kubernetes.io/name: {{ include "app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}


# Create the name of the service account to use
{{- define "app.serviceAccountName" -}}
{{- if and .Values.serviceAccount .Values.serviceAccount.enabled }}
{{- default (include "app.name" .) .Values.serviceAccount.name }}
{{- else }}
{{- include "app.name" . }}
{{- end }}
{{- end }}

# Create app checksum for deployments
{{- define "app.checksums" -}}
{{- if .Values.configMap }}
checksum/configs: {{ toJson .Values.configMap | sha256sum }}
{{- end }}
{{- if .Values.secrets }}
checksum/secrets: {{ toJson .Values.secrets | sha256sum }}
{{- end }}
{{- end }}

# Create imagePullSecret
{{- define "drunk.utils.imagePullSecretName" }}
{{- if .Values.imageCredentials -}}
{{- .Values.imageCredentials.name | default (printf "%s-dcr-secret" (include "app.name" .)) }}
{{- end }}
{{- end }}
{{- define "drunk.utils.imagePullSecret" }}
{{- if .Values.imageCredentials -}}
{{- printf "{\"auths\": {\"%s\": {\"auth\": \"%s\"}}}" .Values.imageCredentials.registry (printf "%s:%s" .Values.imageCredentials.username .Values.imageCredentials.password | b64enc) | b64enc }}
{{- end }}
{{- end }}

# Full drunk-lib.all
{{- define "drunk-lib.all" -}}
{{ include "drunk-lib.configMap" . }}
{{ include "drunk-lib.cronJobs" . }}
{{ include "drunk-lib.deployment" . }}
{{ include "drunk-lib.hpa" . }}
{{ include "drunk-lib.imagePullSecret" . }}
{{ include "drunk-lib.ingress" . }}
{{ include "drunk-lib.jobs" . }}
{{ include "drunk-lib.secrets" . }}
{{ include "drunk-lib.secretProvider" . }}
{{ include "drunk-lib.service" . }}
{{ include "drunk-lib.serviceAccount" . }}
{{ include "drunk-lib.tls" . }}
{{ include "drunk-lib.volumes" . }}
{{- end }}

{{- define "quoteStrings" -}}
{{- /*
Recursively quotes all string values in the given data structure.
*/ -}}
{{- $root := . -}}
{{- if kindIs "map" $root }}
{{- range $key, $value := $root }}
{{- $quotedValue := include "quoteStrings" $value }}
{{- printf "%s: %s" $key $quotedValue | nindent 2 }}
{{- end }}
{{- else if kindIs "slice" $root }}
{{- range $index, $value := $root }}
{{- $quotedValue := include "quoteStrings" $value }}
{{- printf "- %s" $quotedValue | nindent 2 }}
{{- end }}
{{- else if kindIs "string" $root }}
{{- printf "%q" $root }}
{{- else }}
{{- $root }}
{{- end }}
{{- end }}
