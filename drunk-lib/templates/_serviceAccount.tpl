{{/*
Generate ServiceAccount resource for pod authentication
Creates a ServiceAccount when .Values.serviceAccount.enabled is true
Uses .Values.serviceAccount.name if specified, otherwise defaults to app name
Includes optional annotations from .Values.serviceAccount.annotations
*/}}
{{- define "drunk-lib.serviceAccount" -}}
{{- if and .Values.serviceAccount .Values.serviceAccount.enabled -}}
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ include "app.serviceAccountName" . }}
  labels:
    {{- include "app.labels" . | nindent 4 }}
  {{/* Include optional annotations for service account (e.g., for IRSA, Workload Identity) */}}
  {{- with .Values.serviceAccount.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
{{- end }}
{{- end }}