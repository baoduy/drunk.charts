# Template: _hpa.tpl
# Author: Duy Bao (baoduy)
# Repository: https://github.com/baoduy/drunk.charts
# Description: Helm template library for drunk.charts
# Created: 2025-09-10

# Generate HorizontalPodAutoscaler resource for automatic scaling
# Creates an HPA when .Values.autoscaling.enabled is true
# Scales the deployment based on CPU and/or memory utilization
# Requires .Values.autoscaling.minReplicas, .Values.autoscaling.maxReplicas
# Optional: .Values.autoscaling.targetCPUUtilizationPercentage, .Values.autoscaling.targetMemoryUtilizationPercentage
# Optional: .Values.autoscaling.targetKind (default: "Deployment"), .Values.autoscaling.targetApiVersion (default: "apps/v1")
{{- define "drunk-lib.hpa" -}}
{{- if .Values.autoscaling }}
{{- if .Values.autoscaling.enabled }}
---
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: {{ include "app.fullname" . }}
  labels:
    {{- include "app.labels" . | nindent 4 }}
spec:
  # Target workload for scaling.
  # Set autoscaling.targetKind to "StatefulSet" or another workload kind when not scaling a Deployment.
  # Set autoscaling.targetApiVersion if the workload uses a non-standard API group.
  scaleTargetRef:
    apiVersion: {{ .Values.autoscaling.targetApiVersion | default "apps/v1" | quote }}
    kind: {{ .Values.autoscaling.targetKind | default "Deployment" | quote }}
    name: {{ include "app.fullname" . }}
  # Scaling boundaries from values
  minReplicas: {{ .Values.autoscaling.minReplicas }}
  maxReplicas: {{ .Values.autoscaling.maxReplicas }}
  metrics:
    # CPU-based scaling - configure with .Values.autoscaling.targetCPUUtilizationPercentage
    {{- if .Values.autoscaling.targetCPUUtilizationPercentage }}
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: {{ .Values.autoscaling.targetCPUUtilizationPercentage }}
    {{- end }}
    # Memory-based scaling - configure with .Values.autoscaling.targetMemoryUtilizationPercentage
    {{- if .Values.autoscaling.targetMemoryUtilizationPercentage }}
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: {{ .Values.autoscaling.targetMemoryUtilizationPercentage }}
    {{- end }}
{{- end }}
{{- end }}
{{- end }}
