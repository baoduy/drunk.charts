{{- define "drunk-lib.secretProvider" -}}
{{- $sp := .Values.secretProvider -}}
{{- if and $sp $sp.enabled }}
{{- $provider := $sp.provider | default dict -}}
{{- $providerName := $provider.name | default "azure" -}}
{{- $spName := default (printf "%s-spc" (include "app.name" .)) $sp.name -}}
---
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: {{ printf "%s-cls" $spName }}
  labels:
    {{- include "app.labels" . | nindent 4 }}
spec:
  provider: {{ $providerName }}
  parameters:
    usePodIdentity: {{ $provider.usePodIdentity | default false | quote }}
    useWorkloadIdentity: {{ $provider.useWorkloadIdentity | default false | quote }}
    useVMManagedIdentity: {{ $provider.useVMManagedIdentity | default true | quote }}
    userAssignedIdentityID: {{ $provider.userAssignedIdentityID | quote }}
    tenantId: {{ $provider.tenantId | quote }}
    keyvaultName: {{ $provider.vaultName | quote }}
    objects: |
      array:
        {{- if $sp.objects }}
          {{- range $obj := $sp.objects }}
            {{- if kindIs "string" $obj }}
        - |
          objectName: {{ $obj }}
          objectType: secret
          objectVersion: ""
            {{- else }}
        - |
          objectName: {{ $obj.objectName }}
          objectType: {{ $obj.objectType | default "secret" }}
          objectVersion: {{ $obj.objectVersion | default "" | quote }}
            {{- end }}
          {{- end }}
        {{- end }}
  {{- /* secretObjects block: use provided or auto-generate from objects */}}
  {{- $secretObjects := $sp.secretObjects }}
  {{- if not $secretObjects }}
    {{- if $sp.objects }}
      {{- $secretObjects = list }}
      {{- range $obj := $sp.objects }}
        {{- if kindIs "string" $obj }}
          {{- $secretObjects = append $secretObjects (dict "key" $obj "objectName" $obj) }}
        {{- else }}
          {{- $secretObjects = append $secretObjects (dict "key" $obj.objectName "objectName" $obj.objectName) }}
        {{- end }}
      {{- end }}
    {{- end }}
  {{- end }}
  {{- if $secretObjects }}
  secretObjects:
    - secretName: {{ $spName }}
      type: Opaque
      data:
        {{- range $so := $secretObjects }}
        - key: {{ $so.key }}
          objectName: {{ $so.objectName }}
        {{- end }}
  {{- end }}
{{- end }}
{{- end }}
