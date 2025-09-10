# Template: _volumes.tpl
# Author: Duy Bao (baoduy)
# Repository: https://github.com/baoduy/drunk.charts
# Description: Helm template library for drunk.charts
# Created: 2025-09-10

# Generate PersistentVolumeClaim resources for persistent storage
# Creates PVCs for each volume defined in .Values.volumes that is not an emptyDir
# Each PVC is named "<app-name>-<volume-key>" and uses:
# - .Values.volumes.<key>.size (default: "2Gi")
# - .Values.volumes.<key>.accessMode (default: "ReadWriteOnce")
# - .Values.volumes.<key>.storageClassName or .Values.global.storageClassName
# Skips volumes where .Values.volumes.<key>.emptyDir is true
{{- define "drunk-lib.volumes" -}}
{{- $root := . }}
{{- range $k,$v := .Values.volumes }}
# Only create PVC for non-emptyDir volumes
{{- if or (not $v.emptyDir) (not (eq $v.emptyDir true)) }}
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: {{ include "app.name" $root }}-{{ $k }}
  labels:
    {{- include "app.labels" $root | nindent 4 }}
spec:
  resources:
    requests:
      # Storage size from volume config, defaults to 2Gi
      storage: {{ $v.size | default "2Gi" }}
  volumeMode: Filesystem
  accessModes:
    # Access mode from volume config, defaults to ReadWriteOnce
    - {{ $v.accessMode | default "ReadWriteOnce" }}
  # Storage class from volume config or global config
  {{- if $v.storageClassName }}
  storageClassName: {{ $v.storageClassName | quote }}
  {{- else if $root.Values.global.storageClassName }}
  storageClassName: {{ $root.Values.global.storageClassName | quote }}
  {{- end }}
{{- end }}
{{- end }}
{{- end }}