{{- define "nod.labels" -}}
app.kubernetes.io/name: nod
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
helm.sh/chart: nod-{{ .Chart.Version }}
{{- end }}

{{- define "nod.selector" -}}
app.kubernetes.io/name: nod
app.kubernetes.io/component: {{ . }}
{{- end }}

{{- define "nod.image" -}}
{{ index .root.Values.images .name }}:{{ .root.Values.images.tag | default .root.Chart.AppVersion }}
{{- end }}

{{- define "nod.secret" -}}
{{ .Values.existingSecret | default "nod" }}
{{- end }}

{{- define "nod.storageClass" -}}
{{- with .Values.storageClass }}
storageClassName: {{ . }}
{{- end }}
{{- end }}
