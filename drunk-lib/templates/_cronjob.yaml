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
  schedule: "{{ .schedule }}"
  concurrencyPolicy: "{{ .concurrencyPolicy | default "Forbid" }}"
  # Keep only one successful and one failed job history
  successfulJobsHistoryLimit: 1
  failedJobsHistoryLimit: 1
  jobTemplate:
    spec:
      template:
        spec:
          automountServiceAccountToken: false
          {{- if $.Values.global.imagePullSecret }}
          imagePullSecrets:
          - name: {{ $.Values.global.imagePullSecret }}
          {{- end }}
          serviceAccountName: {{ include "app.serviceAccountName" $root }}
          securityContext:
            {{- toYaml $.Values.podSecurityContext | nindent 12 }}
          restartPolicy: {{ .restartPolicy | default "OnFailure" }}
          containers:
          - name: {{ .name }}
            securityContext:
              {{- toYaml $.Values.securityContext | nindent 14 }}
            image: "{{ $.Values.global.image }}:{{ $.Values.global.tag | default $.Chart.AppVersion }}"
            imagePullPolicy: "{{ $.Values.global.imagePullPolicy | default "Always" }}"
            {{- if .command }}
            command: {{- toYaml .command | nindent 12 }}
            {{- end }}
            {{- if .args }}
            args: {{- toYaml .args | nindent 12 }}
            {{- end }}
            {{- if $.Values.env }}
            env:
            {{- range $k,$v := $.Values.env }}
            - name: {{ $k }}
              value: {{ $v | quote }}
            {{- end }}
            {{- end }}
            envFrom:
            {{- if $.Values.configMap }}
              - configMapRef:
                  name: {{ include "app.name" $root }}-config
              {{- end }}
              {{- range $c := $.Values.configFrom }}
              - configMapRef:
                  name: {{ $c }}
              {{- end }}
              {{- if $.Values.secrets }}
              - secretRef:
                  name: {{ include "app.name" $root }}-secret
              {{- end }}
              {{- range $s := $.Values.secretFrom }}
              - secretRef:
                  name: {{ $s }}
              {{- end }}
            resources:
            {{- toYaml $.Values.resources | nindent 14 }}
            
            {{- if $.Values.volumes }}
            volumeMounts:
            {{- range $k,$v := $.Values.volumes }}
              - name: {{ $k }}
                readOnly: {{ $v.readOnly | default false }}
                mountPath: {{ $v.mountPath }}
              {{- if $v.subPath }}
                subPath: {{ $v.subPath }}
              {{- end }}
            {{- end }}
            {{- end }}
        
          {{- if $.Values.volumes }}
          volumes:
          {{- range $k,$v := $.Values.volumes }}
            - name: {{ $k }}
            {{- if $v.emptyDir }}
              emptyDir: {}
            {{- else }}
              persistentVolumeClaim:
                claimName: {{ include "app.name" $root }}-{{ $k }}
            {{- end }}
          {{- end }}
          {{- end }}
{{- end }}
{{- end }}