# Template: _ingress.tpl
# Author: Duy Bao (baoduy)
# Repository: https://github.com/baoduy/drunk.charts
# Description: Helm template library for drunk.charts
# Created: 2025-09-10

# Generate Ingress resource for external access to services
# Creates an Ingress when .Values.ingress.enabled is true
# Requires .Values.ingress.hosts array with host and optional path/pathType/port
# Optional configurations:
# - .Values.ingress.className (default: "nginx")
# - .Values.ingress.annotations for ingress controller specific settings
# - .Values.ingress.tls for TLS certificate secret name
{{- define "drunk-lib.ingress" -}}
{{- if .Values.ingress -}}
{{- if .Values.ingress.enabled -}}
{{- $fullName := include "app.fullname" . -}}
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ $fullName }}
  labels:
    {{- include "app.labels" . | nindent 4 }}
  # Optional annotations for ingress controller configuration
  {{- with .Values.ingress.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  # Ingress class name, defaults to nginx
  ingressClassName: {{ .Values.ingress.className | default "nginx"}}
  # TLS configuration using certificate secret
  {{- if .Values.ingress.tls }}
  tls:
    - hosts:
        {{- range .Values.ingress.hosts }}
        - {{ .host | quote }}
        {{- end }}
      secretName: {{ .Values.ingress.tls }}
  {{- end }}
  # Route rules for each host in .Values.ingress.hosts
  rules:
    {{- range .Values.ingress.hosts }}
    - host: {{ .host | quote }}
      http:
        paths:
          - path: {{ .path | default "/" }}
            pathType: {{ .pathType | default "Prefix" }}
            backend:
              service:
                name: {{ $fullName }}
                port:
                  # Use custom port or auto-detect from deployment ports
                  number: {{ if .port }}{{ .port }}{{ else }}{{ include "drunk.utils.ingressPort" $ }}{{ end }}
    {{- end }}
{{- end }}
{{- end }}
{{- end }}