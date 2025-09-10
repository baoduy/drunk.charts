{{/*
Generate Secret resource from values.secrets
Creates a Secret with name "<app-name>-secret" containing all key-value pairs from .Values.secrets
Uses stringData for easier handling of secret values
Only rendered when .Values.secrets is defined and not empty
*/}}
{{- define "drunk-lib.secrets" -}}
{{- if .Values.secrets -}}
---
apiVersion: "v1"
kind: Secret
metadata:
  name: {{ include "app.name" . }}-secret
stringData:
  {{/* Convert all values from .Values.secrets to properly quoted strings */}}
  {{- include "quoteStrings" .Values.secrets }}
{{- end }}
{{- end }}