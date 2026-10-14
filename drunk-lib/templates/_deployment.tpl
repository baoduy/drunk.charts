# Template: _deployment.tpl
# Author: Duy Bao (baoduy)
# Repository: https://github.com/baoduy/drunk.charts
# Description: Helm template library for drunk.charts
# Created: 2025-09-10

{{- define "drunk-lib.deployment" -}}
{{- $root := . }}
{{- if and .Values.deployment .Values.deployment.enabled -}}
---
# Generate Deployment resource for long-running application workloads
# Creates a Deployment when .Values.deployment.enabled is true
# Supports comprehensive configuration including:
# - Replica count, update strategy, and deployment settings
# - Init containers for setup tasks (.Values.global.initContainer)
# - Main application container with ports, probes, resources
# - Environment variables, secrets, and configmaps
# - Volume mounts for persistent storage and secret management
# - Security contexts, service accounts, and scheduling
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "app.fullname" . }}
  labels:
    {{- include "app.labels" . | nindent 4 }}
    {{- with .Values.deployment.labels }}
    {{- include "drunk-lib.objectLabels" (dict "root" $root "workload" $.Values.deployment "kind" "deployment") | nindent 4 }}
    {{- end }}
  {{- with .Values.deployment.annotations }}
  annotations:
    {{- include "drunk-lib.metadataEntries" . | nindent 4 }}
  {{- end }}
spec:
  {{- $autoscaling := .Values.autoscaling | default dict }}
  {{- if not (and $autoscaling.omitReplicas $autoscaling.enabled (eq ($autoscaling.targetKind | default "Deployment") "Deployment")) }}
  # Replica count from .Values.deployment.replicaCount, defaults to 1
  replicas: {{ .Values.deployment.replicaCount | default 1 }}
  {{- end }}
  {{- range $field := list "minReadySeconds" "progressDeadlineSeconds" "revisionHistoryLimit" }}
  {{- if hasKey $.Values.deployment $field }}
  {{ $field }}: {{ get $.Values.deployment $field }}
  {{- end }}
  {{- end }}
# Deployment strategy configuration
{{- if .Values.deployment.strategy }}
  strategy:
    type: {{ .Values.deployment.strategy.type | default "RollingUpdate" }}
    {{- if or (not .Values.deployment.strategy.type) (eq .Values.deployment.strategy.type "RollingUpdate") }}
    {{- $strategy := .Values.deployment.strategy }}
    {{- $surge := 1 }}
    {{- $unavailable := 0 }}
    {{- if hasKey $strategy "maxSurge" }}{{- $surge = $strategy.maxSurge }}{{- end }}
    {{- if hasKey $strategy "maxUnavailable" }}{{- $unavailable = $strategy.maxUnavailable }}{{- end }}
    {{- if and (has (toString $surge) (list "0" "0%")) (has (toString $unavailable) (list "0" "0%")) }}
    {{- fail "deployment.strategy.maxSurge and deployment.strategy.maxUnavailable must not both be 0" }}
    {{- end }}
    # Rolling update parameters for RollingUpdate strategy
    rollingUpdate:
      maxSurge: {{ $surge }}
      maxUnavailable: {{ $unavailable }}
    {{- end }}
{{- else }}
  # Default strategy: RollingUpdate with safe defaults
  strategy:
    type: "RollingUpdate"
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
{{- end }}
  # Pod selector using standard labels
  selector:
    matchLabels:
      {{- include "app.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      annotations:
        # Checksums trigger pod restart when configs/secrets change
        {{- include "app.checksums" . | nindent 8 }}
        # Additional pod annotations from .Values.deployment.podAnnotations
        {{- with .Values.deployment.podAnnotations }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
      labels:
        {{- include "app.selectorLabels" . | nindent 8 }}
        {{- /* Custom pod labels from .Values.deployment.podLabels; selector keys are refused, values always render as text */}}
        {{- range $k, $v := .Values.deployment.podLabels }}
        {{- if has $k (list "app.kubernetes.io/name" "app.kubernetes.io/instance") }}
        {{- fail (printf "deployment.podLabels: %s is a selector label and cannot be set on Deployment pods" $k) }}
        {{- end }}
        {{ $k }}: {{ $v | quote }}
        {{- end }}
    spec:
      # Security: disable automatic service account token mounting
      automountServiceAccountToken: false
      {{- with .Values.deployment.priorityClassName }}
      priorityClassName: {{ . | quote }}
      {{- end }}
      {{- if hasKey .Values.deployment "terminationGracePeriodSeconds" }}
      terminationGracePeriodSeconds: {{ .Values.deployment.terminationGracePeriodSeconds }}
      {{- end }}
      # Image pull secrets for private registries
      {{- if .Values.global.imagePullSecret }}
      imagePullSecrets:
      - name: {{ .Values.global.imagePullSecret }}
      {{- end }}
      # Service account configuration from .Values.serviceAccount
      {{- if and .Values.serviceAccount .Values.serviceAccount.enabled }}
      serviceAccountName: {{ include "app.serviceAccountName" . }}
      {{- end }}
      # Pod security context from .Values.podSecurityContext
      {{- if .Values.podSecurityContext }}
      securityContext:
        {{- toYaml .Values.podSecurityContext | nindent 8 }}
      {{- end }}
      # Init containers for setup tasks (optional)
      {{- if .Values.global.initContainer }}
      # Begin initContainers - setup tasks that run before main container
      initContainers:
        - name: {{ include "app.name" . }}-init
          # Init container security context
          securityContext:
            {{- toYaml .Values.securityContext | nindent 12 }}
          # Init container image from .Values.global.initContainer.image
          image: "{{ .Values.global.initContainer.image }}"
          imagePullPolicy: "IfNotPresent"
          # Init container command override
          {{- if .Values.global.initContainer.command }}
          command: {{- toYaml .Values.global.initContainer.command | nindent 12 }}
          {{- end }}
          # Init container arguments
          {{- if .Values.global.initContainer.args }}
          args: {{- toYaml .Values.global.initContainer.args | nindent 12 }}
          {{- end }}
          # Environment variables for init container
          {{- if .Values.env }}
          env:
          {{- range $k,$v := .Values.env }}
          - name: {{ $k }}
            {{- include "drunk-lib.envValue" $v | nindent 12 }}
          {{- end }}
          {{- end }}
          # Environment from external sources for init container
          envFrom:
          # ConfigMap created from .Values.configMap
          {{- if .Values.configMap }}
          - configMapRef:
              name: {{ include "app.name" . }}-config
          {{- end }}
          # External ConfigMaps from .Values.configFrom array
          {{- range $c := .Values.configFrom }}
          - configMapRef:
              name: {{ $c }}
          {{- end }}
          # Secret created from .Values.secrets
          {{- if .Values.secrets }}
          - secretRef:
              name: {{ include "app.name" . }}-secret
          {{- end }}
          # External Secrets from .Values.secretFrom array
          {{- range $s := .Values.secretFrom }}
          - secretRef:
              name: {{ $s }}
          {{- end }}
          # SecretProvider volume - Azure Key Vault, AWS Secrets Manager, etc.
          {{- with .Values.secretProvider }}
          {{- if .enabled }}
          - secretRef:
              name: {{ include "app.secretProviderName" $root }}
          {{- end }}
          {{- end }}
          # Init container resource limits and requests
          resources:
            {{- toYaml .Values.resources | nindent 12 }}
          # Volume mounts for init container
          {{- if .Values.volumes }}
          volumeMounts:
          {{- range $k,$v := .Values.volumes }}
            - name: {{ $k }}
              readOnly: {{ $v.readOnly | default false }}
              mountPath: {{ $v.mountPath }}
            {{- if $v.subPath }}
              subPath: {{ $v.subPath }}
            {{- end }}
          {{- end }}
          # SecretProvider volume mount for init container
          {{- with .Values.secretProvider }}
          {{- if .enabled }}
            - name: {{ include "app.secretProviderVolumeName" $root }}
              mountPath: "/mnt/secrets-store"
              readOnly: true
          {{- end }}
          {{- end }}
          {{- end }}
      # End initContainers
      {{- end }}

      # Begin Containers - main application containers
      containers:
        - name: {{ include "app.name" . }}
          # Main container security context from .Values.securityContext
          {{- if .Values.securityContext }}
          securityContext:
            {{- toYaml .Values.securityContext | nindent 12 }}
          {{- end }}
          # Container image from .Values.global.image and .Values.global.tag
          image: "{{ .Values.global.image }}:{{ .Values.global.tag | default .Chart.AppVersion }}"
          imagePullPolicy: "{{ .Values.global.imagePullPolicy | default "Always" }}"
          # Container command override from .Values.deployment.command
          {{- if .Values.deployment.command }}
          command: {{- toYaml .Values.deployment.command | nindent 12 }}
          {{- end }}
          # Container arguments from .Values.deployment.args
          {{- if .Values.deployment.args }}
          args: {{- toYaml .Values.deployment.args | nindent 12 }}
          {{- end }}
          # Container ports from .Values.deployment.ports
          {{- if .Values.deployment.ports }}
          ports:
          {{- range $k,$v := .Values.deployment.ports }}
            - name: {{ $k }}
              containerPort: {{ $v }}
              protocol: TCP
            {{- end }}
          {{- end }}
          {{- include "drunk-lib.probes" (dict "workload" .Values.deployment "kind" "deployment") | nindent 10 }}
          {{- if or (hasKey .Values.deployment "lifecycle") (hasKey .Values.deployment "preStopSleepSeconds") }}
          {{- include "drunk-lib.lifecycle" (dict "workload" .Values.deployment "kind" "deployment") | nindent 10 }}
          {{- end }}
          # Environment variables from .Values.env
          {{- if .Values.env }}
          env:
          {{- range $k,$v := .Values.env }}
          - name: {{ $k }}
            {{- include "drunk-lib.envValue" $v | nindent 12 }}
          {{- end }}
          {{- end }}
          # Environment from external sources
          envFrom:
          # ConfigMap created from .Values.configMap
          {{- if .Values.configMap }}
          - configMapRef:
              name: {{ include "app.name" . }}-config
          {{- end }}
          # External ConfigMaps from .Values.configFrom array
          {{- range $c := .Values.configFrom }}
          - configMapRef:
              name: {{ $c }}
          {{- end }}
          # Secret created from .Values.secrets
          {{- if .Values.secrets }}
          - secretRef:
              name: {{ include "app.name" . }}-secret
          {{- end }}
          # External Secrets from .Values.secretFrom array
          {{- range $s := .Values.secretFrom }}
          - secretRef:
              name: {{ $s }}
          {{- end }}
          # SecretProvider volume - Azure Key Vault, AWS Secrets Manager, etc.
          {{- with .Values.secretProvider }}
          {{- if .enabled }}
          - secretRef:
              name: {{ include "app.secretProviderName" $root }}
          {{- end }}
          {{- end }}
          # Container resource limits and requests from .Values.resources
          resources:
            {{- toYaml .Values.resources | nindent 12 }}
          # Volume mounts for persistent storage and secrets
          {{- if or .Values.volumes (and .Values.secretProvider .Values.secretProvider.enabled) }}
          volumeMounts:
          # Persistent and emptyDir volumes from .Values.volumes
          {{- if .Values.volumes }}
          {{- range $k,$v := .Values.volumes }}
          - name: {{ $k }}
            readOnly: {{ $v.readOnly | default false }}
            mountPath: {{ $v.mountPath }}
            {{- if $v.subPath }}
            subPath: {{ $v.subPath }}
            {{- end }}
          {{- end }}
          {{- end }}
          # SecretProvider volume mount for external secret management
          {{- with .Values.secretProvider }}
          {{- if .enabled }}
          - name: {{ include "app.secretProviderVolumeName" $root }}
            mountPath: "/mnt/secrets-store"
            readOnly: true
          {{- end }}
          {{- end }}
          {{- end }}
      # End Containers
      
      # Volume definitions for the pod
      volumes:
      # Volumes from .Values.volumes - PVCs or emptyDir
      {{- if .Values.volumes }}
      {{- range $k,$v := .Values.volumes }}
      - name: {{ $k }}
        {{- include "drunk-lib.volumeSource" (dict "root" $root "name" $k "volume" $v) | nindent 8 }}
      {{- end }}
      {{- end }}
      # SecretProvider volume for external secret management systems
      {{- with .Values.secretProvider }}
      {{- if .enabled }}
      - name: {{ include "app.secretProviderVolumeName" $root }}
        csi:
          driver: secrets-store.csi.k8s.io
          readOnly: true
          volumeAttributes:
            secretProviderClass: {{ include "app.secretProviderClassName" $root }}
      {{- end }}
      {{- end }}
      
      # Pod scheduling constraints
      # Node selector from .Values.nodeSelector
      {{- with .Values.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- include "drunk-lib.podScheduling" . | nindent 6 }}
      # Pod tolerations from .Values.tolerations
      {{- with .Values.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
{{- end }}
{{- end }}