# Template: _secretprovider.tpl
# Author: Duy Bao (baoduy)
# Repository: https://github.com/baoduy/drunk.charts
# Description: Helm template library for drunk.charts
# Created: 2025-09-10

# Generate SecretProviderClass for external secret management integration
# Creates a SecretProviderClass when .Values.secretProvider.enabled is true
# Supports cloud secret management services like Azure Key Vault, AWS Secrets Manager, GCP Secret Manager
# Configuration through .Values.secretProvider:
# - .provider.name: Provider type (default: "azure")
# - .provider.vaultName: Name of the secret vault/store
# - .provider.tenantId: Cloud tenant ID
# - .provider.userAssignedIdentityID: Identity for vault access
# - .objects: Array of secrets to fetch from vault
# - .secretObjects: Optional custom mapping of vault secrets to k8s secret keys
# Auto-generates Kubernetes Secret from vault objects if .secretObjects not provided
{{- define "drunk-lib.secretProvider" -}}
{{- $sp := .Values.secretProvider -}}
{{- if and $sp $sp.enabled }}
{{- $provider := $sp.provider | default dict -}}
# Provider type: azure, aws, gcp
{{- $providerName := $provider.name | default "azure" -}}
# SecretProviderClass name
{{- $spName := default (printf "%s-spc" (include "app.name" .)) $sp.name -}}
---
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: {{ printf "%s-cls" $spName }}
  labels:
    {{- include "app.labels" . | nindent 4 }}
spec:
  # External secret provider type
  provider: {{ $providerName }}
  # Provider-specific configuration parameters
  parameters:
    # Azure-specific identity configuration
    usePodIdentity: {{ $provider.usePodIdentity | default false | quote }}
    useWorkloadIdentity: {{ $provider.useWorkloadIdentity | default false | quote }}
    useVMManagedIdentity: {{ $provider.useVMManagedIdentity | default true | quote }}
    userAssignedIdentityID: {{ $provider.userAssignedIdentityID | quote }}
    tenantId: {{ $provider.tenantId | quote }}
    # Vault/secret store name
    keyvaultName: {{ $provider.vaultName | quote }}
    # Objects to retrieve from external secret store
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
          objectFormat: {{ $obj.objectFormat | default "" | quote }}
          objectEncoding: {{ $obj.objectEncoding | default "" | quote }}
            {{- end }}
          {{- end }}
        {{- end }}
  # Kubernetes Secret creation from external objects
  {{- $secretObjects := $sp.secretObjects }}
  # Auto-generate secretObjects if not provided
  {{- if not $secretObjects }}
    {{- if $sp.objects }}
      {{- $secretObjects = list }}
      # Create secretObjects mapping from .objects list
      {{- range $obj := $sp.objects }}
        {{- if kindIs "string" $obj }}
          {{- $secretObjects = append $secretObjects (dict "key" $obj "objectName" $obj) }}
        {{- else }}
          {{- $secretObjects = append $secretObjects (dict "key" $obj.objectName "objectName" $obj.objectName) }}
        {{- end }}
      {{- end }}
    {{- end }}
  {{- end }}
  # Create Kubernetes Secret with mapped keys
  {{- if $secretObjects }}
  secretObjects:
    - secretName: {{ $spName }}
      type: Opaque
      data:
        # Map external secret keys to Kubernetes secret keys
        {{- range $so := $secretObjects }}
        - key: {{ $so.key }}
          objectName: {{ $so.objectName }}
        {{- end }}
  {{- end }}
{{- end }}
{{- end }}
