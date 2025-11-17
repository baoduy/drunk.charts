# Template: _gateway.tpl
# Author: Duy Bao (baoduy)
# Repository: https://github.com/baoduy/drunk.charts
# Description: Helm template library for drunk.charts
# Created: 2025-11-17

# Generate Gateway resource for Kubernetes Gateway API
# Creates a Gateway when .Values.gateway.enabled is true
# Requires .Values.gateway.gatewayClassName and .Values.gateway.listeners
# Optional configurations:
# - .Values.gateway.annotations for gateway-specific settings
# - .Values.gateway.listeners array with protocol, port, hostname, and TLS configuration
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
  # Optional annotations for gateway configuration
  {{- with .Values.gateway.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  # Gateway class name defines the controller implementation
  gatewayClassName: {{ .Values.gateway.gatewayClassName | required ".Values.gateway.gatewayClassName is required" }}
  # Listener configuration for protocols, ports, and hostnames
  listeners:
    {{- range .Values.gateway.listeners }}
    - name: {{ .name | required "listener name is required" }}
      protocol: {{ .protocol | default "HTTP" }}
      port: {{ .port | required "listener port is required" }}
      {{- if .hostname }}
      hostname: {{ .hostname | quote }}
      {{- end }}
      {{- if .allowedRoutes }}
      allowedRoutes:
        {{- if .allowedRoutes.namespaces }}
        namespaces:
          {{- if .allowedRoutes.namespaces.from }}
          from: {{ .allowedRoutes.namespaces.from }}
          {{- end }}
          {{- if .allowedRoutes.namespaces.selector }}
          selector:
            {{- toYaml .allowedRoutes.namespaces.selector | nindent 12 }}
          {{- end }}
        {{- end }}
        {{- if .allowedRoutes.kinds }}
        kinds:
          {{- toYaml .allowedRoutes.kinds | nindent 10 }}
        {{- end }}
      {{- end }}
      {{- if .tls }}
      tls:
        {{- if .tls.mode }}
        mode: {{ .tls.mode }}
        {{- end }}
        {{- if .tls.certificateRefs }}
        certificateRefs:
          {{- range .tls.certificateRefs }}
          - kind: {{ .kind | default "Secret" }}
            name: {{ .name | required "certificate name is required" }}
            {{- if .group }}
            group: {{ .group }}
            {{- end }}
            {{- if .namespace }}
            namespace: {{ .namespace }}
            {{- end }}
          {{- end }}
        {{- end }}
        {{- if .tls.options }}
        options:
          {{- toYaml .tls.options | nindent 10 }}
        {{- end }}
      {{- end }}
    {{- end }}
  {{- if .Values.gateway.addresses }}
  addresses:
    {{- toYaml .Values.gateway.addresses | nindent 4 }}
  {{- end }}
{{- end }}
{{- end }}
{{- end }}
