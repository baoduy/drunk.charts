{{- define "drunk-lib.pdb" -}}
{{- $pdb := .Values.podDisruptionBudget | default dict -}}
{{- $deployment := .Values.deployment | default dict -}}
{{- $statefulset := .Values.statefulset | default dict -}}
{{- if and $pdb.enabled (or $deployment.enabled $statefulset.enabled) -}}
{{- if and (hasKey $pdb "minAvailable") (hasKey $pdb "maxUnavailable") -}}
{{- fail "podDisruptionBudget.minAvailable and podDisruptionBudget.maxUnavailable are mutually exclusive" -}}
{{- end -}}
{{- if not (or (hasKey $pdb "minAvailable") (hasKey $pdb "maxUnavailable")) -}}
{{- fail "podDisruptionBudget requires exactly one of minAvailable or maxUnavailable" -}}
{{- end -}}
{{- $workload := ternary $deployment $statefulset (default false $deployment.enabled) -}}
{{- $replicas := $workload.replicaCount | default 1 -}}
{{- $autoscaling := .Values.autoscaling | default dict -}}
{{- if and (hasKey $pdb "minAvailable") (not $autoscaling.enabled) -}}
{{- if and (not (kindIs "string" $pdb.minAvailable)) (ge (int $pdb.minAvailable) (int $replicas)) -}}
{{- fail (printf "podDisruptionBudget.minAvailable (%v) >= replicas (%v) would block every node drain" $pdb.minAvailable $replicas) -}}
{{- end -}}
{{- end -}}
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: {{ include "app.fullname" . }}
  labels:
    {{- include "app.labels" . | nindent 4 }}
spec:
  {{- if hasKey $pdb "minAvailable" }}
  minAvailable: {{ $pdb.minAvailable | toJson }}
  {{- else }}
  maxUnavailable: {{ $pdb.maxUnavailable | toJson }}
  {{- end }}
  unhealthyPodEvictionPolicy: {{ $pdb.unhealthyPodEvictionPolicy | default "AlwaysAllow" }}
  selector:
    matchLabels:
      {{- include "app.selectorLabels" . | nindent 6 }}
{{- end }}
{{- end }}
