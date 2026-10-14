{{/*
Expand the name of the chart.
*/}}
{{- define "workload.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 26 chars so that '<fullname>-<component>-<name>' stays within the 63 chars of DNS labels,
with component names capped at 20 chars and configMaps, secrets and volumeClaims names at 15 chars.
If release name contains chart name it will be used as a full name.
*/}}
{{- define "workload.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 26 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 26 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 26 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Fully qualified name of the rendered component, prefix of its resources names.
Falls back to the fullname when no component is rendered.
*/}}
{{- define "workload.componentName" -}}
{{- if .Component }}
{{- print (include "workload.fullname" .) "-" .Component.Name }}
{{- else }}
{{- include "workload.fullname" . }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "workload.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "workload.labels" -}}
helm.sh/chart: {{ include "workload.chart" . }}
{{ include "workload.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels, with the component name as app.kubernetes.io/component when rendering one.
*/}}
{{- define "workload.selectorLabels" -}}
app.kubernetes.io/name: {{ include "workload.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- with .Component }}
app.kubernetes.io/component: {{ .Name }}
{{- end }}
{{- end }}

{{/*
Ports of the component by name as {port, protocol, servicePort}, read with fromYaml.
*/}}
{{- define "workload.ports" -}}
{{- $servicePorts := (.Component.Values.service | default dict).ports | default dict }}
{{- range $name, $value := .Component.Values.ports }}
{{- $port := kindIs "map" $value | ternary $value (dict "port" $value) }}
{{ $name | quote }}:
  port: {{ $port.port }}
  protocol: {{ $port.protocol | default "TCP" }}
  servicePort: {{ index $servicePorts $name | default $port.port }}
{{- end }}
{{- end }}

{{/*
Create the name of the service account to use, the component one when it declares its own serviceAccount.
*/}}
{{- define "workload.serviceAccountName" -}}
{{- $component := and .Component .Component.Values.serviceAccount }}
{{- $serviceAccount := $component | default .Values.serviceAccount | default dict }}
{{- $fullname := include "workload.fullname" . }}
{{- if $component }}{{ $fullname = include "workload.componentName" . }}{{ end }}
{{- if $serviceAccount.create }}
{{- default $fullname $serviceAccount.name }}
{{- else }}
{{- default "default" $serviceAccount.name }}
{{- end }}
{{- end }}
