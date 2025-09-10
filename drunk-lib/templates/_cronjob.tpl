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
          {{- if and $.Values.serviceAccount $.Values.serviceAccount.enabled }}
          serviceAccountName: {{ include "app.serviceAccountName" $root }}
          {{- end }}
          securityContext:
            {{- toYaml $.Values.podSecurityContext | nindent 12 }}
          restartPolicy: {{ .restartPolicy | default "OnFailure" }}
          containers:
          - name: {{ .name }}
            securityContext:
              {{- toYaml $.Values.securityContext | nindent 14 }}
            image: "{{ .image | default (printf "%s:%s" $.Values.global.image ($.Values.global.tag | default $.Chart.AppVersion)) }}"
            imagePullPolicy: "{{ .imagePullPolicy | default ($.Values.global.imagePullPolicy | default "Always") }}"
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
            # SecretProvider volume

            {{- if .enabled }}
            {{- if and .enabled .secretObjects }}
            - secretRef:
                name: {{ default (printf "%s-spc" (include "app.name" $root)) .name }}
            {{- end }}
            {{- end }}
            resources:
            {{- toYaml $.Values.resources | nindent 14 }}
            
            {{- if or $.Values.volumes (and $.Values.secretProvider $.Values.secretProvider.enabled) }}
            volumeMounts:
            {{- if $.Values.volumes }}
            {{- range $k,$v := $.Values.volumes }}
            - name: {{ $k }}
              readOnly: {{ $v.readOnly | default false }}
              mountPath: {{ $v.mountPath }}
              {{- if $v.subPath }}
              subPath: {{ $v.subPath }}
              {{- end }}
            {{- end }}
            # SecretProvider volume
            {{- end }}
            {{- with $.Values.secretProvider }}
            {{- if .enabled }}
            - name: {{ printf "%s-vol" (default (printf "%s-spc" (include "app.name" $root)) .name) }}
              mountPath: "/mnt/secrets-store"
              readOnly: true
            {{- end }}
            {{- end }}


          volumes:
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
          # SecretProvider volume
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