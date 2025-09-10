{{/*
Generate Docker registry pull secret for private container images
Creates a Secret of type kubernetes.io/dockerconfigjson when .Values.imageCredentials is defined
Uses helper functions to generate the secret name and Docker config JSON
Requires .Values.imageCredentials.registry, .Values.imageCredentials.username, .Values.imageCredentials.password
Optional: .Values.imageCredentials.name (defaults to "<app-name>-dcr-secret")
*/}}
{{- define "drunk-lib.imagePullSecret" -}}
{{- if .Values.imageCredentials }}
---
apiVersion: v1
kind: Secret
metadata:
  name: {{ template "drunk.utils.imagePullSecretName" . }}
type: kubernetes.io/dockerconfigjson
data:
  {{/* Generate Docker config JSON with base64 encoded credentials */}}
  .dockerconfigjson: {{ template "drunk.utils.imagePullSecret" . }}
{{- end }}
{{- end }}