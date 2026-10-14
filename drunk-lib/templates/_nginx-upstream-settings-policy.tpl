{{- define "drunk-lib.nginxUpstreamSettingsPolicy" -}}
{{- $policy := .Values.nginxUpstreamSettingsPolicy | default dict -}}
{{- if $policy.enabled -}}
---
apiVersion: gateway.nginx.org/v1alpha1
kind: UpstreamSettingsPolicy
metadata:
  name: {{ include "app.fullname" . }}-upstream-settings
  namespace: {{ .Release.Namespace | quote }}
  labels:
    {{- include "app.labels" . | nindent 4 }}
spec:
  targetRefs:
    - group: ""
      kind: Service
      name: {{ include "app.fullname" . | quote }}
  {{- with $policy.keepAlive }}
  keepAlive:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with $policy.loadBalancingMethod }}
  loadBalancingMethod: {{ . | quote }}
  {{- end }}
  {{- with $policy.hashMethodKey }}
  hashMethodKey: {{ . | quote }}
  {{- end }}
  {{- with $policy.zoneSize }}
  zoneSize: {{ . | quote }}
  {{- end }}
{{- end }}
{{- end }}
