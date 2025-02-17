{{- define "drunk-lib.secrets" -}}
{{- if .Values.secrets -}}
---
apiVersion: "v1"
kind: Secret
metadata:
  name: {{ include "app.name" . }}-secret
stringData:
  {{- include "quoteStrings" .Values.secrets }}
{{- end }}
{{- end }}