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
  serviceName: {{ include "app.fullname" . }}
  replicas: {{ .Values.statefulset.replicaCount | default 1 }}
  podManagementPolicy: {{ .Values.statefulset.podManagementPolicy | default "OrderedReady" }}
  updateStrategy:
    type: {{ .Values.statefulset.updateStrategy | default "RollingUpdate" }}
  selector:
    matchLabels:
      {{- include "app.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      annotations:
        {{- include "app.checksums" . | nindent 8 }}
        {{- with .Values.statefulset.podAnnotations }}
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
          {{- if .Values.statefulset.command }}
          command: {{- toYaml .Values.statefulset.command | nindent 12 }}
          {{- end }}
          {{- if .Values.statefulset.args }}
          args: {{- toYaml .Values.statefulset.args | nindent 12 }}
          {{- end }}
          {{- if .Values.statefulset.ports }}
          ports:
          {{- range $k,$v := .Values.statefulset.ports }}
            - name: {{ $k }}
              containerPort: {{ $v }}
              protocol: TCP
            {{- end }}
          {{- end }}
          {{- if .Values.statefulset.liveness }}
          livenessProbe:
            initialDelaySeconds: 60
            periodSeconds: 300
            httpGet:
              path: {{ .Values.statefulset.liveness }}
              port: http
          {{- end }}
          {{- if .Values.statefulset.readiness }}
          readinessProbe:
            httpGet:
              path: {{ .Values.statefulset.readiness }}
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
          {{- if or .Values.volumes .Values.statefulset.volumeClaimTemplates }}
          volumeMounts:
          {{- range $k,$v := .Values.volumes }}
            - name: {{ $k }}
              readOnly: {{ $v.readOnly | default false }}
              mountPath: {{ $v.mountPath }}
            {{- if $v.subPath }}
              subPath: {{ $v.subPath }}
            {{- end }}
          {{- end }}
          {{- range $v := .Values.statefulset.volumeClaimTemplates }}
            - name: {{ $v.name }}
              mountPath: {{ $v.mountPath }}
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
  {{- if .Values.statefulset.volumeClaimTemplates }}
  volumeClaimTemplates:
  {{- range $v := .Values.statefulset.volumeClaimTemplates }}
    - metadata:
        name: {{ $v.name }}
      spec:
        accessModes: {{ $v.accessModes | default (list "ReadWriteOnce") }}
        storageClassName: {{ $v.storageClassName }}
        resources:
          requests:
            storage: {{ $v.storage }}
  {{- end }}
  {{- end }}
{{- end }}
{{- end }}