# Template: _statefulset.tpl
# Author: Duy Bao (baoduy)
# Repository: https://github.com/baoduy/drunk.charts
# Description: Helm template library for drunk.charts
# Created: 2025-09-10

# Generate StatefulSet resource for stateful applications requiring persistent identity
# Creates a StatefulSet when .Values.statefulset.enabled is true
# Supports all deployment features plus stateful-specific configurations:
# - Ordered deployment and scaling with persistent pod identities
# - Volume claim templates for automatic PVC provisioning per pod
# - Service name for stable network identity
# - Pod management policies (OrderedReady, Parallel)
# - Update strategies (RollingUpdate, OnDelete)
{{- define "drunk-lib.statefulset" -}}
{{- $root := . }}
{{- if and .Values.statefulset .Values.statefulset.enabled -}}
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: {{ include "app.fullname" . }}
  labels:
    {{- include "app.labels" . | nindent 4 }}
spec:
  # Service name for stable network identity
  serviceName: {{ include "app.fullname" . }}
  # Replica count from .Values.statefulset.replicaCount, defaults to 1
  replicas: {{ .Values.statefulset.replicaCount | default 1 }}
  # Pod management policy: OrderedReady (default) or Parallel
  podManagementPolicy: {{ .Values.statefulset.podManagementPolicy | default "OrderedReady" }}
  # Update strategy: RollingUpdate (default) or OnDelete
  updateStrategy:
    type: {{ .Values.statefulset.updateStrategy | default "RollingUpdate" }}
  # Pod selector using standard labels
  selector:
    matchLabels:
      {{- include "app.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      annotations:
        # Checksums trigger pod restart when configs/secrets change
        {{- include "app.checksums" . | nindent 8 }}
        # Additional pod annotations from .Values.statefulset.podAnnotations
        {{- with .Values.statefulset.podAnnotations }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
      labels:
        {{- include "app.selectorLabels" . | nindent 8 }}
    spec:
      # Security: disable automatic service account token mounting
      automountServiceAccountToken: false
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
            value: {{ $v | quote }}
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
              name: {{ default (printf "%s-spc" (include "app.name" $root)) .name }}
          {{- end }}
          {{- end }}
          # Init container resource limits and requests
          resources:
            {{- toYaml .Values.resources | nindent 12 }}
          # Volume mounts for init container
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
          # SecretProvider volume mount for init container
          {{- with .Values.secretProvider }}
          {{- if .enabled }}
          - name: {{ printf "%s-vol" (default (printf "%s-spc" (include "app.name" $root)) .name) }}
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
          # Container command override from .Values.statefulset.command
          {{- if .Values.statefulset.command }}
          command: {{- toYaml .Values.statefulset.command | nindent 12 }}
          {{- end }}
          # Container arguments from .Values.statefulset.args
          {{- if .Values.statefulset.args }}
          args: {{- toYaml .Values.statefulset.args | nindent 12 }}
          {{- end }}
          # Container ports from .Values.statefulset.ports
          {{- if .Values.statefulset.ports }}
          ports:
          {{- range $k,$v := .Values.statefulset.ports }}
            - name: {{ $k }}
              containerPort: {{ $v }}
              protocol: TCP
            {{- end }}
          {{- end }}
          # Health checks - liveness probe from .Values.statefulset.liveness
          {{- if .Values.statefulset.liveness }}
          livenessProbe:
            initialDelaySeconds: 60
            periodSeconds: 300
            httpGet:
              path: {{ .Values.statefulset.liveness }}
              port: http
          {{- end }}
          # Health checks - readiness probe from .Values.statefulset.readiness
          {{- if .Values.statefulset.readiness }}
          readinessProbe:
            httpGet:
              path: {{ .Values.statefulset.readiness }}
              port: http
          {{- end }}
          # Environment variables from .Values.env
          {{- if .Values.env }}
          env:
          {{- range $k,$v := .Values.env }}
          - name: {{ $k }}
            value: {{ $v | quote }}
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
              name: {{ default (printf "%s-spc" (include "app.name" $root)) .name }}
          {{- end }}
          {{- end }}
          # Container resource limits and requests from .Values.resources
          resources:
            {{- toYaml .Values.resources | nindent 12 }}
          # Volume mounts for persistent storage and secrets
          {{- if or .Values.volumes .Values.statefulset.volumeClaimTemplates (and .Values.secretProvider .Values.secretProvider.enabled) }}
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
          # Volume claim template mounts for StatefulSet persistent storage
          {{- range $v := .Values.statefulset.volumeClaimTemplates }}
          - name: {{ $v.name }}
            mountPath: {{ $v.mountPath }}
          {{- end }}
          # SecretProvider volume mount for external secret management
          {{- with .Values.secretProvider }}
          {{- if .enabled }}
          - name: {{ printf "%s-vol" (default (printf "%s-spc" (include "app.name" $root)) .name) }}
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
        {{- if $v.emptyDir }}
        emptyDir: {}
        {{- else }}
        persistentVolumeClaim:
          claimName: {{ include "app.name" $root }}-{{ $k }}
        {{- end }}
      {{- end }}
      {{- end }}
      # SecretProvider volume for external secret management systems
      {{- with .Values.secretProvider }}
      {{- if .enabled }}
      - name: {{ printf "%s-vol" (default (printf "%s-spc" (include "app.name" $root)) .name) }}
        csi:
          driver: secrets-store.csi.k8s.io
          readOnly: true
          volumeAttributes:
            secretProviderClass: {{ printf "%s-cls" (default (printf "%s-spc" (include "app.name" $root)) .name) }}
      {{- end }}
      {{- end }}

      # Pod scheduling constraints
      # Node selector from .Values.nodeSelector
      {{- with .Values.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      # Pod affinity rules from .Values.affinity
      {{- with .Values.affinity }}
      affinity:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      # Pod tolerations from .Values.tolerations
      {{- with .Values.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
  # Volume claim templates for StatefulSet automatic PVC provisioning
  {{- if .Values.statefulset.volumeClaimTemplates }}
  volumeClaimTemplates:
  {{- range $v := .Values.statefulset.volumeClaimTemplates }}
    - metadata:
        name: {{ $v.name }}
      spec:
        # Access modes from template config, defaults to ReadWriteOnce
        accessModes: {{ $v.accessModes | default (list "ReadWriteOnce") }}
        # Storage class from template config
        storageClassName: {{ $v.storageClassName }}
        resources:
          requests:
            # Storage size from template config
            storage: {{ $v.storage }}
  {{- end }}
  {{- end }}
{{- end }}
{{- end }}