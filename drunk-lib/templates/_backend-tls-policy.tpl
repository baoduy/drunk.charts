{{- /* Include BackendTLSPolicy if httpRoute is enabled and tlsValidation is not null */ -}}
{{- define "drunk-lib.backendTlsPolicy" -}}
{{- if and (ne .Values.httpRoute nil) .Values.httpRoute.enabled .Values.httpRoute.tlsValidation -}}
---
apiVersion: networking.k8s.io/v1
kind: BackendTLSPolicy
metadata:
  name: {{ include "app.fullname" . }}-tls-policy
  namespace: {{ .Values.httpRoute.namespace | default .Release.Namespace }}
spec:
  options:
    tls-verify-depth: "1"
  targetRefs:
    - group: ""
      kind: Service
      name: {{ include "app.fullname" . }}
  validation:
    {{- if .Values.httpRoute.hostnames }}
    hostName: {{ (index .Values.httpRoute.hostnames 0) }}
    {{- end }}
    {{- toYaml .Values.httpRoute.tlsValidation | nindent 4 }}

{{- end }}
{{- end }}