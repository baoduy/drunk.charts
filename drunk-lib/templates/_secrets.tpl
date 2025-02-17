{{- define "drunk-lib.secrets" -}}
{{- if .Values.secrets -}}
---
apiVersion: "v1"
kind: Secret
metadata:
  name: {{ include "app.name" . }}-secret
stringData:
  {{- toYaml .Values.secrets | quote | nindent 2 }}
{{- end }}
{{- end }}