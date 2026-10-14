{{- /* Include BackendTLSPolicy if httpRoute is enabled and tlsValidation is not null */ -}}
{{- define "drunk-lib.backendTlsPolicy" -}}
{{- if and (ne .Values.httpRoute nil) .Values.httpRoute.enabled .Values.httpRoute.tlsValidation -}}
{{- $policy := .Values.backendTlsPolicy | default dict -}}
{{- $validation := deepCopy .Values.httpRoute.tlsValidation -}}
{{- if $policy.hostname -}}
{{- $_ := set $validation "hostname" $policy.hostname -}}
{{- else if and (not $validation.hostname) .Values.httpRoute.hostnames -}}
{{- $_ := set $validation "hostname" (index .Values.httpRoute.hostnames 0) -}}
{{- end -}}
---
apiVersion: gateway.networking.k8s.io/v1
kind: BackendTLSPolicy
metadata:
  name: {{ include "app.fullname" . }}-tls-policy
  namespace: {{ .Release.Namespace | quote }}
spec:
  options:
    {{- if hasKey $policy "options" }}
    {{- toYaml $policy.options | nindent 4 }}
    {{- else }}
    tls-verify-depth: "1"
    {{- end }}
  targetRefs:
    - group: ""
      kind: Service
      name: {{ include "app.fullname" . }}
      sectionName: {{ $policy.sectionName | default "https" | quote }}
  validation:
    {{- toYaml $validation | nindent 4 }}

{{- end }}
{{- end }}
