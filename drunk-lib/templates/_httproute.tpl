---
{{- define "drunk-lib.backendTLSPolicy" -}}
{{- if and .Values.httpRoute (and .Values.httpRoute.enabled .Values.httpRoute.tlsValidation) }}
{{- $fullName := include "app.fullname" . -}}
---
apiVersion: gateway.networking.k8s.io/v1
kind: BackendTLSPolicy
metadata:
  name: {{ $fullName }}-tls-policy
  labels:
    {{- include "app.labels" . | nindent 4 }}
spec:
  # Use first hostname from httpRoute
  {{- $host := (index .Values.httpRoute.hostnames 0) }}
  host: {{ $host | quote }}
  targetRef:
    name: {{ index .Values.httpRoute.parentRefs 0.name | default $fullName }}
    namespace: {{ index .Values.httpRoute.parentRefs 0.namespace | default "default" }}
  validation:
    {{- toYaml .Values.httpRoute.tlsValidation | nindent 4 }}
{{- end }}
{{- end }}
---