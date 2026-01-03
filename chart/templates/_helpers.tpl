{{- define "videor.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "videor.fullname" -}}
{{- printf "%s-%s" .Release.Name (default .Chart.Name .Values.nameOverride) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
