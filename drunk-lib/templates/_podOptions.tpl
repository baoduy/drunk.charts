{{/* Environment values keep their legacy string form unless valueFrom is supplied. */}}
{{- define "drunk-lib.envValue" -}}
{{- if and (kindIs "map" .) (hasKey . "valueFrom") -}}
valueFrom:
  {{- toYaml .valueFrom | nindent 2 }}
{{- else -}}
value: {{ . | quote }}
{{- end -}}
{{- end -}}

{{/* Select one source for pod volumes and PVC generation; empty emptyDir maps retain their PVC. */}}
{{- define "drunk-lib.volumeType" -}}
{{- $sources := list -}}
{{- range $key := list "configMap" "secret" "projected" "csi" "emptyDir" -}}
{{- if hasKey $ $key -}}
{{- $sources = append $sources $key -}}
{{- end -}}
{{- end -}}
{{- if gt (len $sources) 1 -}}
{{- fail (printf "volumes: only one source key may be set; found %s" (join ", " $sources)) -}}
{{- end -}}
{{- if and (eq (len $sources) 1) (ne (first $sources) "emptyDir") -}}
{{- first $sources -}}
{{- else if .emptyDir -}}
emptyDir
{{- else -}}
persistentVolumeClaim
{{- end -}}
{{- end -}}

{{- define "drunk-lib.volumeSource" -}}
{{- $type := include "drunk-lib.volumeType" .volume -}}
{{- if eq $type "persistentVolumeClaim" -}}
persistentVolumeClaim:
  claimName: {{ include "app.name" .root }}-{{ .name }}
{{- else if and (eq $type "emptyDir") (not (kindIs "map" .volume.emptyDir)) -}}
emptyDir: {}
{{- else -}}
{{ $type }}:
  {{- toYaml (get .volume $type) | nindent 2 }}
{{- end -}}
{{- end -}}

{{/* Kubernetes labels and annotations are strings, including numeric and boolean inputs. */}}
{{- define "drunk-lib.metadataEntries" -}}
{{- range $key, $value := . }}
{{ $key }}: {{ $value | quote }}
{{- end -}}
{{- end -}}

{{- define "drunk-lib.objectLabels" -}}
{{- $standard := include "app.labels" .root | fromYaml -}}
{{- range $key, $value := .workload.labels }}
{{- if hasKey $standard $key }}
{{- fail (printf "%s.labels: %s is a standard label and cannot be overridden" $.kind $key) }}
{{- end }}
{{ $key }}: {{ $value | quote }}
{{- end -}}
{{- end -}}

{{/* Jobs inherit node placement only. Presence, rather than truthiness, controls overrides. */}}
{{- define "drunk-lib.jobScheduling" -}}
{{- range $key := list "nodeSelector" "tolerations" -}}
{{- $value := get $.root.Values $key -}}
{{- if hasKey $.job $key -}}
{{- $value = get $.job $key -}}
{{- end -}}
{{- with $value }}
{{ $key }}:
  {{- toYaml . | nindent 2 }}
{{- end -}}
{{- end -}}
{{- $affinity := dict -}}
{{- $appAffinity := .root.Values.affinity | default dict -}}
{{- with $appAffinity.nodeAffinity -}}
{{- $_ := set $affinity "nodeAffinity" . -}}
{{- end -}}
{{- if hasKey .job "affinity" -}}
{{- $affinity = .job.affinity -}}
{{- end -}}
{{- with $affinity }}
affinity:
  {{- toYaml . | nindent 2 }}
{{- end -}}
{{- end -}}

{{- define "drunk-lib.jobPodMetadata" -}}
{{- if or .podLabels .podAnnotations -}}
metadata:
  {{- with .podLabels }}
  labels:
    {{- include "drunk-lib.metadataEntries" . | nindent 4 }}
  {{- end }}
  {{- with .podAnnotations }}
  annotations:
    {{- include "drunk-lib.metadataEntries" . | nindent 4 }}
  {{- end }}
{{- end -}}
{{- end -}}
