# Template: _httproute.tpl
# Author: Duy Bao (baoduy)
# Repository: https://github.com/baoduy/drunk.charts
# Description: Helm template library for drunk.charts
# Created: 2025-11-17

# Generate HTTPRoute resource for Kubernetes Gateway API
# Creates an HTTPRoute when .Values.httpRoute.enabled is true
# Requires .Values.httpRoute.parentRefs to reference Gateway
# Requires .Values.httpRoute.rules array with matches and backendRefs
# Optional configurations:
# - .Values.httpRoute.annotations for route-specific settings
# - .Values.httpRoute.hostnames for host matching
# - .Values.httpRoute.rules[].filters for request manipulation
{{- define "drunk-lib.httpRoute" -}}
{{- if .Values.httpRoute -}}
{{- if .Values.httpRoute.enabled -}}
{{- $fullName := include "app.fullname" . -}}
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: {{ $fullName }}
  labels:
    {{- include "app.labels" . | nindent 4 }}
  # Optional annotations for route configuration
  {{- with .Values.httpRoute.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  # Reference to parent Gateway(s)
  parentRefs:
    {{- if .Values.httpRoute.parentRefs }}
    {{- range .Values.httpRoute.parentRefs }}
    - name: {{ .name | default $fullName }}
      {{- if .namespace }}
      namespace: {{ .namespace }}
      {{- end }}
      {{- if .sectionName }}
      sectionName: {{ .sectionName }}
      {{- end }}
      {{- if .port }}
      port: {{ .port }}
      {{- end }}
    {{- end }}
    {{- else }}
    # Default to referencing the gateway with the same name
    - name: {{ $fullName }}
    {{- end }}
  # Optional hostnames for routing
  {{- if .Values.httpRoute.hostnames }}
  hostnames:
    {{- range .Values.httpRoute.hostnames }}
    - {{ . | quote }}
    {{- end }}
  {{- end }}
  # Routing rules
  rules:
    {{- range .Values.httpRoute.rules }}
    {{- if .matches }}
    - matches:
        {{- range .matches }}
        {{- if .path }}
        - path:
            type: {{ .path.type | default "PathPrefix" }}
            value: {{ .path.value | default "/" }}
          {{- if .method }}
          method: {{ .method }}
          {{- end }}
          {{- if .headers }}
          headers:
            {{- range .headers }}
            - type: {{ .type | default "Exact" }}
              name: {{ .name | required "header name is required" }}
              value: {{ .value | required "header value is required" }}
            {{- end }}
          {{- end }}
          {{- if .queryParams }}
          queryParams:
            {{- range .queryParams }}
            - type: {{ .type | default "Exact" }}
              name: {{ .name | required "query param name is required" }}
              value: {{ .value | required "query param value is required" }}
            {{- end }}
          {{- end }}
        {{- else }}
        - path:
            type: PathPrefix
            value: /
        {{- end }}
        {{- end }}
      {{- else }}
    - matches:
        - path:
            type: PathPrefix
            value: /
      {{- end }}
      {{- if .filters }}
      filters:
        {{- range .filters }}
        - type: {{ .type | required "filter type is required" }}
          {{- if eq .type "RequestRedirect" }}
          requestRedirect:
            {{- if .requestRedirect.scheme }}
            scheme: {{ .requestRedirect.scheme }}
            {{- end }}
            {{- if .requestRedirect.hostname }}
            hostname: {{ .requestRedirect.hostname }}
            {{- end }}
            {{- if .requestRedirect.path }}
            path:
              {{- toYaml .requestRedirect.path | nindent 14 }}
            {{- end }}
            {{- if .requestRedirect.port }}
            port: {{ .requestRedirect.port }}
            {{- end }}
            {{- if .requestRedirect.statusCode }}
            statusCode: {{ .requestRedirect.statusCode }}
            {{- end }}
          {{- else if eq .type "RequestHeaderModifier" }}
          requestHeaderModifier:
            {{- if .requestHeaderModifier.set }}
            set:
              {{- toYaml .requestHeaderModifier.set | nindent 14 }}
            {{- end }}
            {{- if .requestHeaderModifier.add }}
            add:
              {{- toYaml .requestHeaderModifier.add | nindent 14 }}
            {{- end }}
            {{- if .requestHeaderModifier.remove }}
            remove:
              {{- toYaml .requestHeaderModifier.remove | nindent 14 }}
            {{- end }}
          {{- else if eq .type "URLRewrite" }}
          urlRewrite:
            {{- if .urlRewrite.hostname }}
            hostname: {{ .urlRewrite.hostname }}
            {{- end }}
            {{- if .urlRewrite.path }}
            path:
              {{- toYaml .urlRewrite.path | nindent 14 }}
            {{- end }}
          {{- else if eq .type "RequestMirror" }}
          requestMirror:
            backendRef:
              {{- toYaml .requestMirror.backendRef | nindent 14 }}
          {{- else if eq .type "ExtensionRef" }}
          extensionRef:
            {{- toYaml .extensionRef | nindent 12 }}
          {{- end }}
        {{- end }}
      {{- end }}
      backendRefs:
        {{- if .backendRefs }}
        {{- range .backendRefs }}
        - name: {{ .name | default $fullName }}
          {{- if .namespace }}
          namespace: {{ .namespace }}
          {{- end }}
          port: {{ if .port }}{{ .port }}{{ else }}{{ include "drunk.utils.ingressPort" $ }}{{ end }}
          {{- if .weight }}
          weight: {{ .weight }}
          {{- end }}
          {{- if .filters }}
          filters:
            {{- toYaml .filters | nindent 12 }}
          {{- end }}
        {{- end }}
        {{- else }}
        # Default backend reference to the service
        - name: {{ $fullName }}
          port: {{ include "drunk.utils.ingressPort" $ }}
        {{- end }}
    {{- end }}
{{- end }}
{{- end }}
{{- end }}
