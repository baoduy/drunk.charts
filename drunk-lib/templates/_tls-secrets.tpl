# Template: _tls-secrets.tpl
# Author: Duy Bao (baoduy)
# Repository: https://github.com/baoduy/drunk.charts
# Description: Helm template library for drunk.charts
# Created: 2025-09-10

# Generate TLS Secret resources from certificate files or inline content
# Creates TLS Secrets for each entry in .Values.tlsSecrets where enabled is true (default)
# Each TLS secret requires certificate and private key from either:
# - Files: .crtFile and .keyFile (loaded from chart files)
# - Inline: .crt and .key (base64 encoded values)
# Optional CA certificate can be provided via .caFile or .ca
# Secret naming: "tls-<key>" where key is from .Values.tlsSecrets map
{{- define "drunk-lib.tls" -}}
{{- $root := . }}
{{- $files := .Files }}
{{- range $k, $v := .Values.tlsSecrets }}
# Create TLS secret if enabled (default true)
{{- if or (eq $v.enabled true) (eq $v.enabled nil) }}
---
apiVersion: v1
kind: Secret
metadata:
  name: tls-{{ $k }}
type: kubernetes.io/tls
data:
  # TLS certificate: from file or inline content
  tls.crt: |
    {{- if $v.crtFile }}
    {{ $files.Get $v.crtFile | b64enc }}
    {{- else if $v.crt }}
    {{ $v.crt | b64enc }}
    {{- else }}
    {{- fail "tls.crt or tls.crtFile must be provided for tlsSecrets." }}
    {{- end }}
  # TLS private key: from file or inline content
  tls.key: |
    {{- if $v.keyFile }}
    {{ $files.Get $v.keyFile | b64enc }}
    {{- else if $v.key }}
    {{ $v.key | b64enc }}
    {{- else }}
    {{- fail "tls.key or tls.keyFile must be provided for tlsSecrets." }}
    {{- end }}
  # Optional CA certificate: from file or inline content
  {{- if or $v.ca $v.caFile }}
  ca.crt: |
    {{- if $v.caFile }}
    {{ $files.Get $v.caFile | b64enc }}
    {{- else if $v.ca }}
    {{ $v.ca | b64enc }}
    {{- end }}
  {{- end }}
{{- end }}
{{- end }}
{{- end }}