{{- define "drunk-lib.tls" -}}
{{- $root := . }}
{{- $files := .Files }}
{{- range $k, $v := .Values.tlsSecrets }}
{{- if or (eq $v.enabled true) (eq $v.enabled nil) }}
---
apiVersion: v1
kind: Secret
metadata:
  name: tls-{{ $k }}
type: kubernetes.io/tls
data:
  tls.crt: |
    {{- if $v.crtFile }}
    {{ $files.Get $v.crtFile | b64enc }}
    {{- else if $v.crt }}
    {{ $v.crt | b64enc }}
    {{- else }}
    {{- fail "tls.crt or tls.crtFile must be provided for tlsSecrets." }}
    {{- end }}
  tls.key: |
    {{- if $v.keyFile }}
    {{ $files.Get $v.keyFile | b64enc }}
    {{- else if $v.key }}
    {{ $v.key | b64enc }}
    {{- else }}
    {{- fail "tls.key or tls.keyFile must be provided for tlsSecrets." }}
    {{- end }}
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