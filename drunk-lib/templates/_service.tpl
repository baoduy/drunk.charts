{{- define "drunk-lib.service" -}}
{{- if and .Values.deployment .Values.service }}
{{- if and .Values.deployment.ports (ne .Values.service.enabled false) }}
---
apiVersion: v1
kind: Service
metadata:
  name: {{ include "app.fullname" . }}
  labels: {{ include "app.labels" . | nindent 4 }}
spec:
  type: {{ .Values.service.type | default "ClusterIP" }}
  ports:
    {{- range $k,$v := .Values.deployment.ports}}
    - port: {{ $v }}
      targetPort: {{ $k }}
      protocol: TCP
      name: {{ $k }}
    {{- end }}
  selector: {{ include "app.selectorLabels" . | nindent 4 }}
{{- end }}
{{- end }}
{{- end }}