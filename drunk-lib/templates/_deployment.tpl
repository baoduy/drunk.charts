{{- define "drunk-lib.deployment" -}}
{{- $root := . }}
{{- if and .Values.deployment .Values.deployment.enabled -}}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "app.fullname" . }}
  labels:
    {{- include "app.labels" . | nindent 4 }}
spec:
  replicas: {{ .Values.deployment.replicaCount | default 1 }}
  selector:
    matchLabels:
      {{- include "app.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      annotations:
        {{- include "app.checksums" . | nindent 8 }}
        {{- with .Values.deployment.podAnnotations }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
      labels:
        {{- include "app.selectorLabels" . | nindent 8 }}
    spec:
      automountServiceAccountToken: false
      {{- if .Values.global.imagePullSecret }}
      imagePullSecrets:
      - name: {{ .Values.global.imagePullSecret }}
      {{- end }}
      {{- if and .Values.serviceAccount .Values.serviceAccount.enabled }}
      serviceAccountName: {{ include "app.serviceAccountName" . }}
      {{- end }}
      {{- if .Values.podSecurityContext }}
      securityContext:
        {{- toYaml .Values.podSecurityContext | nindent 8 }}
      {{- end }}
      {{- if .Values.global.initContainer }}
      # Begin initContainers
      initContainers:
        - name: {{ include "app.name" . }}-init
          securityContext:
            {{- toYaml .Values.securityContext | nindent 12 }}
          image: "{{ .Values.global.initContainer.image }}"
          imagePullPolicy: "IfNotPresent"
          {{- if .Values.global.initContainer.command }}
          command: {{- toYaml .Values.global.initContainer.command | nindent 12 }}
          {{- end }}
          {{- if .Values.global.initContainer.args }}
          args: {{- toYaml .Values.global.initContainer.args | nindent 12 }}
          {{- end }}
          {{- if .Values.env }}
          env:
          {{- range $k,$v := .Values.env }}
          - name: {{ $k }}
            value: {{ $v | quote }}
          {{- end }}
          {{- end }}
          envFrom:
          {{- if .Values.configMap }}
            - configMapRef:
                name: {{ include "app.name" . }}-config
          {{- end }}
          {{- range $c := .Values.configFrom }}
            - configMapRef:
                name: {{ $c }}
          {{- end }}
          {{- if .Values.secrets }}
            - secretRef:
                name: {{ include "app.name" . }}-secret
          {{- end }}
          {{- range $s := .Values.secretFrom }}
            - secretRef:
                name: {{ $s }}
          {{- end }}
          resources:
            {{- toYaml .Values.resources | nindent 12 }}
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
          {{- end }}
      # End initContainers
      {{- end }}

      # Begin Containers
      containers:
        - name: {{ include "app.name" . }}
          {{- if .Values.securityContext }}
          securityContext:
            {{- toYaml .Values.securityContext | nindent 12 }}
          {{- end }}
          image: "{{ .Values.global.image }}:{{ .Values.global.tag | default .Chart.AppVersion }}"
          imagePullPolicy: "{{ .Values.global.imagePullPolicy | default "Always" }}"
          {{- if .Values.deployment.command }}
          command: {{- toYaml .Values.deployment.command | nindent 12 }}
          {{- end }}
          {{- if .Values.deployment.args }}
          args: {{- toYaml .Values.deployment.args | nindent 12 }}
          {{- end }}
          {{- if .Values.deployment.ports }}
          ports:
          {{- range $k,$v := .Values.deployment.ports }}
            - name: {{ $k }}
              containerPort: {{ $v }}
              protocol: TCP
            {{- end }}
          {{- end }}
          {{- if .Values.deployment.liveness }}
          livenessProbe:
            initialDelaySeconds: 60
            periodSeconds: 300
            httpGet:
              path: {{ .Values.deployment.liveness }}
              port: http
          {{- end }}
          {{- if .Values.deployment.readiness }}
          readinessProbe:
            httpGet:
              path: {{ .Values.deployment.readiness }}
              port: http
          {{- end }}
          {{- if .Values.env }}
          env:
          {{- range $k,$v := .Values.env }}
          - name: {{ $k }}
            value: {{ $v | quote }}
          {{- end }}
          {{- end }}
          envFrom:
          {{- if .Values.configMap }}
          - configMapRef:
              name: {{ include "app.name" . }}-config
          {{- end }}
          {{- range $c := .Values.configFrom }}
          - configMapRef:
              name: {{ $c }}
          {{- end }}
          {{- if .Values.secrets }}
          - secretRef:
              name: {{ include "app.name" . }}-secret
          {{- end }}
          {{- range $s := .Values.secretFrom }}
          - secretRef:
              name: {{ $s }}
          {{- end }}
          resources:
            {{- toYaml .Values.resources | nindent 12 }}
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
          {{- end }}
      # End Containers
      
      {{- if .Values.volumes }}
      volumes:
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
      
      {{- with .Values.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.affinity }}
      affinity:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
{{- end }}
{{- end }}