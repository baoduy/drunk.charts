{{/*
Generate ConfigMap resource from values.configMap
Creates a ConfigMap with name "<app-name>-config" containing all key-value pairs from .Values.configMap
Only rendered when .Values.configMap is defined and not empty
*/}}
{{- define "drunk-lib.configMap" -}}
{{- if .Values.configMap -}}
---
apiVersion: "v1"
kind: ConfigMap
metadata:
  name: {{ include "app.name" . }}-config
data:
  {{/* Convert all values from .Values.configMap to properly quoted strings */}}
  {{- include "quoteStrings" .Values.configMap }}
{{- end }}
{{- end }}