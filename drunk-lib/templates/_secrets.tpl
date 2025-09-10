# Template: _secrets.tpl
# Author: Duy Bao (baoduy)
# Repository: https://github.com/baoduy/drunk.charts
# Description: Helm template library for drunk.charts
# Created: 2025-09-10

{{- define "drunk-lib.secrets" -}}
{{- if .Values.secrets -}}
---
# Generate Secret resource from values.secrets
# Creates a Secret with name "<app-name>-secret" containing all key-value pairs from .Values.secrets
# Uses stringData for easier handling of secret values
# Only rendered when .Values.secrets is defined and not empty
apiVersion: "v1"
kind: Secret
metadata:
  name: {{ include "app.name" . }}-secret
stringData:
  # Convert all values from .Values.secrets to properly quoted strings
  {{- include "quoteStrings" .Values.secrets }}
{{- end }}
{{- end }}