{{- /* Include BackendTLSPolicy if httpRoute is enabled and tlsValidation is not null */ -}}
{{- if and .Values.httpRoute.enabled .Values.httpRoute.tlsValidation -}}
---
apiVersion: networking.k8s.io/v1
kind: BackendTLSPolicy
metadata:
  name: {{ .Values.httpRoute.name }}-tls-policy
  namespace: {{ .Values.httpRoute.namespace | default .Release.Namespace }}
spec:
  targetRef:
    apiGroup: networking.k8s.io
    kind: HTTPRoute
    name: {{ .Values.httpRoute.name }}
  
  {{- if .Values.httpRoute.hostnames }}
  hostName: {{ (index .Values.httpRoute.hostnames 0) }}
  {{- end }}

  validation: 
    {{- toYaml .Values.httpRoute.tlsValidation | nindent 4 }}
{{- end }}