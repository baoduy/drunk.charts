# Template: _gateway.tpl
# Author: Duy Bao (baoduy)
# Repository: https://github.com/baoduy/drunk.charts
# Description: Helm template library for drunk.charts
# Created: 2026-04-29

# Generate Gateway resource for the Kubernetes Gateway API
# Creates a Gateway when .Values.gateway.enabled is true
# Required:
#   - .Values.gateway.gatewayClassName
#   - .Values.gateway.listeners (array of listener specs)
# Each listener supports: name, protocol, port, hostname, tls, allowedRoutes
{{- define "drunk-lib.gateway" -}}
{{- if .Values.gateway -}}
{{- if .Values.gateway.enabled -}}
{{- $fullName := include "app.fullname" . -}}
---
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: {{ $fullName }}
  labels:
    {{- include "app.labels" . | nindent 4 }}
  {{- with .Values.gateway.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  gatewayClassName: {{ .Values.gateway.gatewayClassName | required "gateway.gatewayClassName is required" | quote }}
  listeners:
    {{- range .Values.gateway.listeners }}
    - name: {{ .name | required "gateway.listeners[].name is required" | quote }}
      protocol: {{ .protocol | required "gateway.listeners[].protocol is required" | quote }}
      port: {{ .port | required "gateway.listeners[].port is required" }}
      {{- if .hostname }}
      hostname: {{ .hostname | quote }}
      {{- end }}
      {{- with .allowedRoutes }}
      allowedRoutes:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .tls }}
      tls:
        {{- if .mode }}
        mode: {{ .mode | quote }}
        {{- end }}
        {{- with .certificateRefs }}
        certificateRefs:
          {{- range . }}
          - name: {{ .name | quote }}
            {{- if .namespace }}
            namespace: {{ .namespace | quote }}
            {{- end }}
            {{- if .group }}
            group: {{ .group | quote }}
            {{- end }}
            {{- if .kind }}
            kind: {{ .kind | quote }}
            {{- end }}
          {{- end }}
        {{- end }}
        {{- with .options }}
        options:
          {{- toYaml . | nindent 10 }}
        {{- end }}
      {{- end }}
    {{- end }}
{{- end }}
{{- end }}
{{- end }}
