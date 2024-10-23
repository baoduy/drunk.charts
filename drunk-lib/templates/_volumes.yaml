{{- define "drunk-lib.volumes" -}}
{{- $root := . }}
{{- range $k,$v := .Values.volumes }}
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
      storage: {{ $v.size | default "2Gi" }}
  volumeMode: Filesystem
  accessModes:
    - {{ $v.accessMode | default "ReadWriteOnce" }}
  {{- if $v.storageClassName }}
  storageClassName: {{ $v.storageClassName | quote }}
  {{- else if $root.Values.global.storageClassName }}
  storageClassName: {{ $root.Values.global.storageClassName | quote }}
  {{- end }}
{{- end }}
{{- end }}
{{- end }}