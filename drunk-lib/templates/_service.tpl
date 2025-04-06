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
    {{- if eq (len .Values.deployment.ports) 1 }}
    - port: 80
      targetPort: {{ keys .Values.deployment.ports | first }}
      protocol: TCP
      name: {{ keys .Values.deployment.ports | first }}
    {{- else }}
    {{- range $k,$v := .Values.deployment.ports}}
    - port: {{ $v }}
      targetPort: {{ $k }}
      protocol: TCP
      name: {{ $k }}
    {{- end }}
    {{- end }}
  selector: {{ include "app.selectorLabels" . | nindent 4 }}
{{- end }}
{{- end }}
{{- end }}