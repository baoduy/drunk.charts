# Template: _cronjob.tpl
# Author: Duy Bao (baoduy)
# Repository: https://github.com/baoduy/drunk.charts
# Description: Helm template library for drunk.charts
# Created: 2025-09-10

# Generate CronJob resources for scheduled task execution
# Creates CronJob resources for each job defined in .Values.cronJobs array
# Each cronJob requires 'name' and 'schedule' fields and supports:
# - .schedule (cron expression for scheduling)
# - .concurrencyPolicy (defaults to "Forbid")
# - .image (defaults to .Values.global.image:tag)
# - .imagePullPolicy (defaults to .Values.global.imagePullPolicy or "Always")
# - .command and .args for container execution
# - .restartPolicy (defaults to "OnFailure")
# CronJobs inherit environment variables, secrets, configmaps, and volumes from global values
{{- define "drunk-lib.cronJobs" -}}
{{- $root := . }}
{{- range .Values.cronJobs }}
---
apiVersion: batch/v1
kind: CronJob
metadata:
  name: {{ include "app.name" $root }}-{{ .name }}
  labels:
    {{- include "app.labels" $root | nindent 4 }}
spec:
  # Cron schedule expression (e.g., "0 2 * * *" for daily at 2 AM)
  schedule: "{{ .schedule }}"
  # Concurrency policy: Forbid, Allow, or Replace
  concurrencyPolicy: "{{ .concurrencyPolicy | default "Forbid" }}"
  # Keep only one successful and one failed job history (cleanup old jobs)
  successfulJobsHistoryLimit: 1
  failedJobsHistoryLimit: 1
  jobTemplate:
    spec:
      template:
        spec:
          # Security: disable automatic service account token mounting
          automountServiceAccountToken: false
          # Image pull secrets for private registries
          {{- if $.Values.global.imagePullSecret }}
          imagePullSecrets:
          - name: {{ $.Values.global.imagePullSecret }}
          {{- end }}
          # Service account configuration from .Values.serviceAccount
          {{- if and $.Values.serviceAccount $.Values.serviceAccount.enabled }}
          serviceAccountName: {{ include "app.serviceAccountName" $root }}
          {{- end }}
          # Pod security context from .Values.podSecurityContext
          securityContext:
            {{- toYaml $.Values.podSecurityContext | nindent 12 }}
          # Job restart policy
          restartPolicy: {{ .restartPolicy | default "OnFailure" }}
          containers:
          - name: {{ .name }}
            # Container security context from .Values.securityContext
            securityContext:
              {{- toYaml $.Values.securityContext | nindent 14 }}
            # Container image: job-specific or global image
            image: "{{ .image | default (printf "%s:%s" $.Values.global.image ($.Values.global.tag | default $.Chart.AppVersion)) }}"
            imagePullPolicy: "{{ .imagePullPolicy | default ($.Values.global.imagePullPolicy | default "Always") }}"
            # Job-specific command override
            {{- if .command }}
            command: {{- toYaml .command | nindent 12 }}
            {{- end }}
            # Job-specific arguments
            {{- if .args }}
            args: {{- toYaml .args | nindent 12 }}
            {{- end }}
            # Environment variables from .Values.env
            {{- if $.Values.env }}
            env:
            {{- range $k,$v := $.Values.env }}
            - name: {{ $k }}
              value: {{ $v | quote }}
            {{- end }}
            {{- end }}
            # Environment from external sources
            envFrom:
            # ConfigMap created from .Values.configMap
            {{- if $.Values.configMap }}
            - configMapRef:
                name: {{ include "app.name" $root }}-config
            {{- end }}
            # External ConfigMaps from .Values.configFrom array
            {{- range $c := $.Values.configFrom }}
            - configMapRef:
                name: {{ $c }}
            {{- end }}
            # Secret created from .Values.secrets
            {{- if $.Values.secrets }}
            - secretRef:
                name: {{ include "app.name" $root }}-secret
            {{- end }}
            # External Secrets from .Values.secretFrom array
            {{- range $s := $.Values.secretFrom }}
            - secretRef:
                name: {{ $s }}
            {{- end }}
            # SecretProvider volume - Azure Key Vault, AWS Secrets Manager, etc.

            {{- if .enabled }}
            {{- if and .enabled .secretObjects }}
            - secretRef:
                name: {{ default (printf "%s-spc" (include "app.name" $root)) .name }}
            {{- end }}
            {{- end }}
            # Resource limits and requests from .Values.resources
            resources:
            {{- toYaml $.Values.resources | nindent 14 }}
            
            # Volume mounts for persistent storage and secrets
            {{- if or $.Values.volumes (and $.Values.secretProvider $.Values.secretProvider.enabled) }}
            volumeMounts:
            # Persistent and emptyDir volumes from .Values.volumes
            {{- if $.Values.volumes }}
            {{- range $k,$v := $.Values.volumes }}
            - name: {{ $k }}
              readOnly: {{ $v.readOnly | default false }}
              mountPath: {{ $v.mountPath }}
              {{- if $v.subPath }}
              subPath: {{ $v.subPath }}
              {{- end }}
            {{- end }}
            # SecretProvider volume mount for external secret management
            {{- end }}
            {{- with $.Values.secretProvider }}
            {{- if .enabled }}
            - name: {{ printf "%s-vol" (default (printf "%s-spc" (include "app.name" $root)) .name) }}
              mountPath: "/mnt/secrets-store"
              readOnly: true
            {{- end }}
            {{- end }}


          # Volume definitions
          volumes:
          # Volumes from .Values.volumes - PVCs or emptyDir
          {{- if $.Values.volumes }}
          {{- range $k,$v := $.Values.volumes }}
          - name: {{ $k }}
            {{- if $v.emptyDir }}
            emptyDir: {}
            {{- else }}
            persistentVolumeClaim:
              claimName: {{ include "app.name" $root }}-{{ $k }}
            {{- end }}
          {{- end }}
          # SecretProvider volume for external secret management systems
          {{- end }}
          {{- with $.Values.secretProvider }}
          {{- if .enabled }}
          - name: {{ printf "%s-vol" (default (printf "%s-spc" (include "app.name" $root)) .name) }}
            csi:
              driver: secrets-store.csi.k8s.io
              readOnly: true
              volumeAttributes:
                secretProviderClass: {{ printf "%s-cls" (default (printf "%s-spc" (include "app.name" $root)) .name) }}
          {{- end }}
          {{- end }}
{{- end }}
{{- end }}