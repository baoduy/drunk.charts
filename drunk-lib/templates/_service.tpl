{{- /* Template: _service.tpl                                                */ -}}
{{- /* Renders a Service. Port source: service.ports → deployment.ports.     */ -}}
{{- /* Set service.enabled: false to suppress even when ports are defined.   */ -}}
{{- define "drunk-lib.service" -}}
{{- $svc := .Values.service | default dict -}}
{{- $ports := dict -}}
{{- if and (kindIs "map" $svc) $svc.ports (kindIs "map" $svc.ports) -}}
  {{- $ports = $svc.ports -}}
{{- else if and .Values.deployment (kindIs "map" .Values.deployment) .Values.deployment.ports -}}
  {{- $ports = .Values.deployment.ports -}}
{{- end -}}
{{- $enabled := not (and (kindIs "map" $svc) (eq (toString (index $svc "enabled")) "false")) -}}
{{- if and (gt (len $ports) 0) $enabled }}
---
# Service — exposes the application's ports inside the cluster.
# Port source resolution: service.ports → deployment.ports
# Set service.enabled: false to suppress this resource.
apiVersion: v1
kind: Service
metadata:
  name: {{ include "app.fullname" . }}
  labels: {{ include "app.labels" . | nindent 4 }}
spec:
  type: {{ (and (kindIs "map" $svc) $svc.type) | default "ClusterIP" }}
  ports:
{{- if eq (len $ports) 1 }}
    - port: 80
      targetPort: {{ keys $ports | first }}
      protocol: TCP
      name: {{ keys $ports | first }}
{{- else }}
{{- range $k, $v := $ports }}
    - port: {{ $v }}
      targetPort: {{ $k }}
      protocol: TCP
      name: {{ $k }}
{{- end }}
{{- end }}
  selector: {{ include "app.selectorLabels" . | nindent 4 }}
{{- end }}
{{- end }}
