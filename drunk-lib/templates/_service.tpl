{{- /* Template: _service.tpl                                                */ -}}
{{- /* Renders a Service. Port source: service.ports → deployment.ports.     */ -}}
{{- /* Set service.enabled: false to suppress even when ports are defined.   */ -}}
{{- /* service.annotations   — extra metadata annotations (e.g. Azure        */ -}}
{{- /*   internal LB: service.beta.kubernetes.io/azure-load-balancer-internal). */ -}}
{{- /* service.loadBalancerIP — static IP for type: LoadBalancer             */ -}}
{{- /*   (e.g. AKS fixed private IP "192.168.123.222").                      */ -}}
{{- /* service.port — exposed port for the single-port case (default 80).    */ -}}
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
  {{- with $svc.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  type: {{ (and (kindIs "map" $svc) $svc.type) | default "ClusterIP" }}
  {{- with $svc.loadBalancerIP }}
  # Static IP for type: LoadBalancer (e.g. AKS fixed private IP).
  loadBalancerIP: {{ . }}
  {{- end }}
  ports:
{{- if eq (len $ports) 1 }}
    - port: {{ (and (kindIs "map" $svc) $svc.port) | default 80 }}
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
