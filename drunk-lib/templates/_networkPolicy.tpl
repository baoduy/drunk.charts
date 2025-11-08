# Template: _networkPolicy.tpl
# Author: Duy Bao (baoduy)
# Repository: https://github.com/baoduy/drunk.charts
# Description: Helm template library for NetworkPolicy resources
# Created: 2025-11-08

{{- define "drunk-lib.networkPolicies" -}}
{{- $root := . }}

{{- /* Support legacy single networkPolicy configuration */ -}}
{{- if and .Values.networkPolicy (not .Values.networkPolicies) }}
---
# NetworkPolicy resource (legacy single policy configuration)
# Creates a NetworkPolicy when .Values.networkPolicy is defined
# Controls network access to pods using labels, namespaces, and CIDR blocks
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: {{ include "app.fullname" . }}{{ .Values.networkPolicy.nameSuffix | default "" }}
  labels:
    {{- include "app.labels" . | nindent 4 }}
spec:
  podSelector:
    {{- if .Values.networkPolicy.podSelector }}
    matchLabels:
      {{- toYaml .Values.networkPolicy.podSelector | nindent 6 }}
    {{- else }}
    matchLabels:
      {{- include "app.selectorLabels" . | nindent 6 }}
    {{- end }}
  policyTypes:
    {{- toYaml .Values.networkPolicy.policyTypes | nindent 4 }}
  {{- if .Values.networkPolicy.ingress }}
  ingress:
    {{- toYaml .Values.networkPolicy.ingress | nindent 4 }}
  {{- end }}
  {{- if .Values.networkPolicy.egress }}
  egress:
    {{- toYaml .Values.networkPolicy.egress | nindent 4 }}
  {{- end }}
{{- end }}

{{- /* Support new multiple networkPolicies configuration */ -}}
{{- if .Values.networkPolicies }}
{{- range $policy := .Values.networkPolicies }}
{{- if or (not (hasKey $policy "enabled")) $policy.enabled }}
---
# NetworkPolicy resource (multi-policy configuration)
# Creates a NetworkPolicy for each entry in .Values.networkPolicies
# Each policy controls network access to pods using labels, namespaces, and CIDR blocks
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: {{ include "app.fullname" $root }}{{ $policy.nameSuffix | default (printf "-%s" $policy.name) }}
  labels:
    {{- include "app.labels" $root | nindent 4 }}
    {{- with $policy.labels }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
spec:
  podSelector:
    {{- if $policy.podSelector }}
    matchLabels:
      {{- toYaml $policy.podSelector | nindent 6 }}
    {{- else }}
    matchLabels:
      {{- include "app.selectorLabels" $root | nindent 6 }}
    {{- end }}
  policyTypes:
    {{- toYaml $policy.policyTypes | nindent 4 }}
  {{- if $policy.ingress }}
  ingress:
    {{- toYaml $policy.ingress | nindent 4 }}
  {{- end }}
  {{- if $policy.egress }}
  egress:
    {{- toYaml $policy.egress | nindent 4 }}
  {{- end }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}
