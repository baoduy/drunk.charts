# Template: _tls-secrets.tpl
# Author: Duy Bao (baoduy)
# Repository: https://github.com/baoduy/drunk.charts
# Description: Helm template library for drunk.charts
# Created: 2025-09-10

# Generate TLS Secret resources from certificate files or inline content
# Creates TLS Secrets for each entry in .Values.tlsSecrets where enabled is true (default)
# Each TLS secret requires certificate and private key from either:
# - Files: .crtFile and .keyFile (loaded from chart files)
# - Inline: .crt and .key (already base64-encoded values)
# Optional CA certificate can be provided via .caFile or .ca
# Secret naming: "tls-<key>" where key is from .Values.tlsSecrets map
{{- define "drunk-lib.tls" -}}
{{- $files := .Files -}}
{{- range $k, $v := .Values.tlsSecrets }}
{{- if or (eq $v.enabled true) (eq $v.enabled nil) }}
{{- $crt := "" -}}
{{- $crtFromFile := false -}}
{{- if $v.crtFile -}}{{- $crt = $files.Get $v.crtFile -}}{{- $crtFromFile = true -}}{{- else if $v.crt -}}{{- $crt = $v.crt -}}{{- end -}}
{{- $key := "" -}}
{{- $keyFromFile := false -}}
{{- if $v.keyFile -}}{{- $key = $files.Get $v.keyFile -}}{{- $keyFromFile = true -}}{{- else if $v.key -}}{{- $key = $v.key -}}{{- end -}}
{{- $ca := "" -}}
{{- $caFromFile := false -}}
{{- if $v.caFile -}}{{- $ca = $files.Get $v.caFile -}}{{- $caFromFile = true -}}{{- else if $v.ca -}}{{- $ca = $v.ca -}}{{- end -}}
{{- if not $crt }}{{- fail (printf "tlsSecrets.%s requires crt or crtFile" $k) }}{{- end }}
{{- if not $key }}{{- fail (printf "tlsSecrets.%s requires key or keyFile" $k) }}{{- end }}
---
apiVersion: v1
kind: Secret
metadata:
  name: tls-{{ $k }}
type: kubernetes.io/tls
data:
  tls.crt: {{ if $crtFromFile }}{{ $crt | b64enc | quote }}{{ else }}{{ $crt | quote }}{{ end }}
  tls.key: {{ if $keyFromFile }}{{ $key | b64enc | quote }}{{ else }}{{ $key | quote }}{{ end }}
  {{- if $ca }}
  ca.crt: {{ if $caFromFile }}{{ $ca | b64enc | quote }}{{ else }}{{ $ca | quote }}{{ end }}
  {{- end }}
{{- end }}
{{- end }}
{{- end }}
