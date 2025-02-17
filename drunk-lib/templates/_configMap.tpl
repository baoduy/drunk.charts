{{- define "drunk-lib.configMap" -}}
{{- if .Values.configMap -}}
---
apiVersion: "v1"
kind: ConfigMap
metadata:
  name: {{ include "app.name" . }}-config
data:
  {{- include "quoteStrings" .Values.configMap }}
{{- end }}
{{- end }}