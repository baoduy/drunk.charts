# Template: _helpers.tpl
# Author: Duy Bao (baoduy)
# Repository: https://github.com/baoduy/drunk.charts
# Description: Helm template library for drunk.charts
# Created: 2025-09-10

# Get the mapped service port for ingress
# Prefer service.ports over deployment.ports. One port maps to 80; no ports maps to 8080.
# With multiple ports, prefer http; otherwise choose the alphabetically first port name.
# Usage: {{ include "drunk.utils.ingressPort" . }}
{{- define "drunk.utils.ingressPort" -}}
{{- $svc := .Values.service | default dict -}}
{{- $ports := dict -}}
{{- if and (kindIs "map" $svc) $svc.ports (kindIs "map" $svc.ports) -}}
  {{- $ports = $svc.ports -}}
{{- else if and .Values.deployment (kindIs "map" .Values.deployment) .Values.deployment.ports -}}
  {{- $ports = .Values.deployment.ports -}}
{{- end -}}
{{- if gt (len $ports) 0 -}}
  {{- if eq (len $ports) 1 -}}
80
  {{- else -}}
    {{- if hasKey $ports "http" -}}
    {{- get $ports "http" -}}
    {{- else -}}
    {{- $firstPort := (keys $ports | sortAlpha | first) -}}
    {{- get $ports $firstPort -}}
    {{- end -}}
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
{{- define "drunk.utils.imagePullSecretName" -}}
{{- if .Values.imageCredentials -}}
{{- .Values.imageCredentials.name | default (printf "%s-dcr-secret" (include "app.name" .)) }}
{{- end -}}
{{- end -}}

{{- define "drunk.utils.imagePullSecret" -}}
{{- if .Values.imageCredentials -}}
{{- printf "{\"auths\": {\"%s\": {\"auth\": \"%s\"}}}" .Values.imageCredentials.registry (printf "%s:%s" .Values.imageCredentials.username .Values.imageCredentials.password | b64enc) | b64enc }}
{{- end -}}
{{- end -}}

# SecretProviderClass naming helpers — pass the root context (`.` or `$`).
# The base name resolves to .Values.secretProvider.name when set, otherwise <app.name>-spc.
{{- define "app.secretProviderName" -}}
{{- $sp := .Values.secretProvider | default dict -}}
{{- default (printf "%s-spc" (include "app.name" .)) $sp.name -}}
{{- end -}}

{{- define "app.secretProviderVolumeName" -}}
{{- printf "%s-vol" (include "app.secretProviderName" .) -}}
{{- end -}}

{{- define "app.secretProviderClassName" -}}
{{- printf "%s-cls" (include "app.secretProviderName" .) -}}
{{- end -}}

# Full drunk-lib.all
{{- define "drunk-lib.all" -}}
{{ include "drunk-lib.backendTlsPolicy" . }}
{{ include "drunk-lib.configMap" . }}
{{ include "drunk-lib.cronJobs" . }}
{{ include "drunk-lib.deployment" . }}
{{ include "drunk-lib.gateway" . }}
{{ include "drunk-lib.hpa" . }}
{{ include "drunk-lib.httpRoute" . }}
{{ include "drunk-lib.imagePullSecret" . }}
{{ include "drunk-lib.ingress" . }}
{{ include "drunk-lib.jobs" . }}
{{ include "drunk-lib.networkPolicies" . }}
{{ include "drunk-lib.nginxUpstreamSettingsPolicy" . }}
{{ include "drunk-lib.nginxClientSettingsPolicy" . }}
{{ include "drunk-lib.pdb" . }}
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


{{/* Shared main-container probes. Keep legacy strings and comments byte-identical. */}}
{{- define "drunk-lib.probes" -}}
{{- $w := .workload -}}
# Health checks - liveness probe from .Values.{{ .kind }}.liveness
{{- if $w.liveness }}
livenessProbe:
  {{- if kindIs "map" $w.liveness }}
  {{- toYaml $w.liveness | nindent 2 }}
  {{- else }}
  initialDelaySeconds: 60
  periodSeconds: 300
  httpGet:
    path: {{ $w.liveness }}
    port: http
  {{- end }}
{{- end }}
# Health checks - readiness probe from .Values.{{ .kind }}.readiness
{{- if $w.readiness }}
readinessProbe:
  {{- if kindIs "map" $w.readiness }}
  {{- toYaml $w.readiness | nindent 2 }}
  {{- else }}
  httpGet:
    path: {{ $w.readiness }}
    port: http
  {{- end }}
{{- end }}
{{- if $w.startup }}
startupProbe:
  {{- if kindIs "map" $w.startup }}
  {{- toYaml $w.startup | nindent 2 }}
  {{- else }}
  httpGet:
    path: {{ $w.startup }}
    port: http
  periodSeconds: 5
  failureThreshold: 30
  {{- end }}
{{- end }}
{{- end }}

{{/* Validate shutdown settings even when the raw lifecycle takes precedence. */}}
{{- define "drunk-lib.lifecycle" -}}
{{- $w := .workload -}}
{{- if and (hasKey $w "preStopSleepSeconds") (hasKey $w "terminationGracePeriodSeconds") -}}
{{- if ge (int $w.preStopSleepSeconds) (int $w.terminationGracePeriodSeconds) -}}
{{- fail (printf "%s.preStopSleepSeconds (%v) must be less than terminationGracePeriodSeconds (%v)" .kind $w.preStopSleepSeconds $w.terminationGracePeriodSeconds) -}}
{{- end -}}
{{- end -}}
{{- if hasKey $w "lifecycle" -}}
lifecycle:
  {{- toYaml $w.lifecycle | nindent 2 }}
{{- else if hasKey $w "preStopSleepSeconds" -}}
lifecycle:
  preStop:
    sleep:
      seconds: {{ $w.preStopSleepSeconds }}
{{- end }}
{{- end }}

{{/* Work on copies: aliases and other includes must not inherit mutated values. */}}
{{- define "drunk-lib.podScheduling" -}}
{{- $affinity := deepCopy (.Values.affinity | default dict) -}}
{{- $preset := "" -}}
{{- if hasKey .Values "podAntiAffinityPreset" -}}
{{- $preset = .Values.podAntiAffinityPreset -}}
{{- end -}}
{{- if not (has $preset (list "" "soft" "hard")) -}}
{{- fail "podAntiAffinityPreset must be one of \"\", soft, hard" -}}
{{- end -}}
{{- $labels := include "app.selectorLabels" . | fromYaml -}}
{{- if and (has $preset (list "soft" "hard")) (not (hasKey $affinity "podAntiAffinity")) -}}
{{- $term := dict "topologyKey" "kubernetes.io/hostname" "labelSelector" (dict "matchLabels" $labels) -}}
{{- if eq $preset "soft" -}}
{{- $_ := set $affinity "podAntiAffinity" (dict "preferredDuringSchedulingIgnoredDuringExecution" (list (dict "weight" 100 "podAffinityTerm" $term))) -}}
{{- else -}}
{{- $_ := set $affinity "podAntiAffinity" (dict "requiredDuringSchedulingIgnoredDuringExecution" (list $term)) -}}
{{- end -}}
{{- end -}}
# Pod affinity rules from .Values.affinity
{{- with $affinity }}
affinity:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with .Values.topologySpreadConstraints }}
topologySpreadConstraints:
  {{- range . }}
  {{- $constraint := deepCopy . }}
  {{- if not (hasKey $constraint "labelSelector") }}
  {{- $_ := set $constraint "labelSelector" (dict "matchLabels" $labels) }}
  {{- end }}
  {{- toYaml (list $constraint) | nindent 2 }}
  {{- end }}
{{- end }}
{{- end }}
