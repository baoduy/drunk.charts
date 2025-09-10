# Template: _configMap.tpl
# Author: Duy Bao (baoduy)
# Repository: https://github.com/baoduy/drunk.charts
# Description: Helm template library for drunk.charts
# Created: 2025-09-10

{{- define "drunk-lib.configMap" -}}
{{- if .Values.configMap -}}
---
# Generate ConfigMap resource from values.configMap
# Creates a ConfigMap with name "<app-name>-config" containing all key-value pairs from .Values.configMap
# Only rendered when .Values.configMap is defined and not empty
apiVersion: "v1"
kind: ConfigMap
metadata:
  name: {{ include "app.name" . }}-config
data:
  # Convert all values from .Values.configMap to properly quoted strings
  {{- include "quoteStrings" .Values.configMap }}
{{- end }}
{{- end }}