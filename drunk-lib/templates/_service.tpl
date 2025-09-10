# Template: _service.tpl
# Author: Duy Bao (baoduy)
# Repository: https://github.com/baoduy/drunk.charts
# Description: Helm template library for drunk.charts
# Created: 2025-09-10

{{- define "drunk-lib.service" -}}
{{- if and .Values.deployment .Values.deployment.ports }}
---
# Generate Service resource to expose deployment ports
# Creates a Service only when .Values.deployment.ports is defined (requires deployment with ports)
# Service type defaults to ClusterIP, can be overridden with .Values.service.type
# For single port: exposes on port 80 targeting the named port
# For multiple ports: creates port mapping for each defined port
apiVersion: v1
kind: Service
metadata:
  name: {{ include "app.fullname" . }}
  labels: {{ include "app.labels" . | nindent 4 }}
spec:
  # Service type: ClusterIP (default), NodePort, LoadBalancer, or ExternalName
  type: {{ if and (.Values.service) (kindIs "map" .Values.service) }}{{ .Values.service.type | default "ClusterIP" }}{{ else }}ClusterIP{{ end }}
  ports:
# For single port deployment, expose on standard port 80
{{- if eq (len .Values.deployment.ports) 1 }}
    - port: 80
      targetPort: {{ keys .Values.deployment.ports | first }}
      protocol: TCP
      name: {{ keys .Values.deployment.ports | first }}
# For multiple ports, map each port individually
{{- else }}
{{- range $k,$v := .Values.deployment.ports }}
    - port: {{ $v }}
      targetPort: {{ $k }}
      protocol: TCP
      name: {{ $k }}
{{- end }}
{{- end }}
  # Select pods using standard selector labels
  selector: {{ include "app.selectorLabels" . | nindent 4 }}
{{- end }}
{{- end }}
