{{- define "drunk-lib.ingress" -}}
{{- if .Values.ingress -}}
{{- if .Values.ingress.enabled -}}
{{- $fullName := include "app.fullname" . -}}
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ $fullName }}
  labels:
    {{- include "app.labels" . | nindent 4 }}
  {{- with .Values.ingress.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  ingressClassName: {{ .Values.ingress.className | default "nginx"}}
  {{- if .Values.ingress.tls }}
  tls:
    - hosts:
        {{- range .Values.ingress.hosts }}
        - {{ .host | quote }}
        {{- end }}
      secretName: {{ .Values.ingress.tls }}
  {{- end }}
  rules:
    {{- range .Values.ingress.hosts }}
    - host: {{ .host | quote }}
      http:
        paths:
          - path: {{ .path | default "/" }}
            pathType: {{ .pathType | default "Prefix" }}
            backend:
              service:
                name: {{ $fullName }}
                port:
                  number: {{ .port | default 8080 }}
    {{- end }}
{{- end }}
{{- end }}
{{- end }}