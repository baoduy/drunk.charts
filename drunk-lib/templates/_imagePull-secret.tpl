{{- define "drunk-lib.imagePullSecret" -}}
{{- if .Values.imageCredentials }}
---
apiVersion: v1
kind: Secret
metadata:
  name: {{ template "drunk.utils.imagePullSecretName" . }}
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: {{ template "drunk.utils.imagePullSecret" . }}
{{- end }}
{{- end }}