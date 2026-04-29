# Template: _tls-secrets.tpl
# Author: Duy Bao (baoduy)
# Repository: https://github.com/baoduy/drunk.charts
# Description: Helm template library for drunk.charts
# Created: 2025-09-10

# Generate TLS Secret resources from certificate files or inline content
# Creates TLS Secrets for each entry in .Values.tlsSecrets where enabled is true (default)
# Each TLS secret requires certificate and private key from either:
# - Files: .crtFile and .keyFile (loaded from chart files)
# - Inline: .crt and .key (raw PEM, base64-encoded by this template)
# Optional CA certificate can be provided via .caFile or .ca
# Secret naming: "tls-<key>" where key is from .Values.tlsSecrets map
{{- define "drunk-lib.tls" -}}
{{- $files := .Files -}}
{{- range $k, $v := .Values.tlsSecrets }}
{{- if or (eq $v.enabled true) (eq $v.enabled nil) }}
{{- $crt := "" -}}
{{- if $v.crtFile -}}{{- $crt = $files.Get $v.crtFile -}}{{- else if $v.crt -}}{{- $crt = $v.crt -}}{{- end -}}
{{- $key := "" -}}
{{- if $v.keyFile -}}{{- $key = $files.Get $v.keyFile -}}{{- else if $v.key -}}{{- $key = $v.key -}}{{- end -}}
{{- $ca := "" -}}
{{- if $v.caFile -}}{{- $ca = $files.Get $v.caFile -}}{{- else if $v.ca -}}{{- $ca = $v.ca -}}{{- end -}}
{{- if not $crt }}{{- fail (printf "tlsSecrets.%s requires crt or crtFile" $k) }}{{- end }}
{{- if not $key }}{{- fail (printf "tlsSecrets.%s requires key or keyFile" $k) }}{{- end }}
---
apiVersion: v1
kind: Secret
metadata:
  name: tls-{{ $k }}
type: kubernetes.io/tls
data:
  tls.crt: {{ $crt | b64enc }}
  tls.key: {{ $key | b64enc }}
  {{- if $ca }}
  ca.crt: {{ $ca | b64enc }}
  {{- end }}
{{- end }}
{{- end }}
{{- end }}
