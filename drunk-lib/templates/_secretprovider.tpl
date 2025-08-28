{{- define "drunk-lib.secretProvider" -}}
{{- $sp := .Values.secretProvider -}}
{{- if and $sp $sp.enabled }}
{{- $spName := default (printf "%s-spc" (include "app.name" .)) $sp.name -}}
---
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: {{ printf "%s-cls" $spName }}
  labels:
    {{- include "app.labels" . | nindent 4 }}
spec:
  provider: {{ $sp.provider | default "azure" }}
  parameters:
    usePodIdentity: {{ $sp.usePodIdentity | default false | quote }}
    useWorkloadIdentity: {{ $sp.useWorkloadIdentity | default false | quote }}
    useVMManagedIdentity: {{ $sp.useVMManagedIdentity | default true | quote }}
    userAssignedIdentityID: {{ $sp.userAssignedIdentityID | quote }}
    tenantId: {{ $sp.tenantId | quote }}
    keyvaultName: {{ $sp.vaultName | quote }}
    objects: |
      array:
        {{- range $sp.objects }}
        - |
          objectName: {{ .objectName }}
          objectType: {{ .objectType }}
          {{- if .objectVersion }}
          objectVersion: {{ .objectVersion }}
          {{- end }}
        {{- end }}
  {{- if $sp.secretObjects }}
  secretObjects:
    {{- range $so := $sp.secretObjects }}
    - secretName: {{ $spName }}
      type: {{ $so.type | default "Opaque" }}
      data:
        {{- range $item := $so.data }}
        - key: {{ $item.key }}
          objectName: {{ $item.objectName }}
        {{- end }}
    {{- end }}
  {{- end }}
{{- end }}
{{- end }}
