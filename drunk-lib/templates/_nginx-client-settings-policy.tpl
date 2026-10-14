{{- define "drunk-lib.nginxClientSettingsPolicy" -}}
{{- $policy := .Values.nginxClientSettingsPolicy | default dict -}}
{{- if $policy.enabled -}}
---
apiVersion: gateway.nginx.org/v1alpha1
kind: ClientSettingsPolicy
metadata:
  name: {{ include "app.fullname" . }}-client-settings
  namespace: {{ .Release.Namespace | quote }}
  labels:
    {{- include "app.labels" . | nindent 4 }}
spec:
  targetRef:
    group: gateway.networking.k8s.io
    kind: HTTPRoute
    name: {{ include "app.fullname" . | quote }}
  {{- with $policy.body }}
  body:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with $policy.keepAlive }}
  keepAlive:
    {{- toYaml . | nindent 4 }}
  {{- end }}
{{- end }}
{{- end }}
