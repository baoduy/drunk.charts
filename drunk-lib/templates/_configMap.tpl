{{- define "drunk-lib.configMap" -}}
{{- if .Values.configMap -}}
---
apiVersion: "v1"
kind: ConfigMap
metadata:
  name: {{ include "app.name" . }}-config
data:
{{- toYaml .Values.configMap | nindent 2 }}
{{- end }}
{{- end }}