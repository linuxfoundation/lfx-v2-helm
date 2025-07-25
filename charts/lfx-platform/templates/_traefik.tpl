{{/*
Copyright The Linux Foundation and each contributor to LFX.
SPDX-License-Identifier: MIT
*/}}

{{/*
Determine if HTTPS is enabled and get the HTTPS listener name in a single loop
*/}}
{{- define "lfx-platform.https-enabled" -}}
{{- $httpsEnabled := false -}}
{{- if .Values.traefik.gateway.listeners -}}
  {{- range $name, $listener := .Values.traefik.gateway.listeners -}}
    {{- if eq $listener.protocol "HTTPS" -}}
      {{- $httpsEnabled = true -}}
      {{- break -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- $httpsEnabled -}}
{{- end -}}

{{/*
Get the HTTPS listener name (sectionName) from gateway listeners
*/}}
{{- define "lfx-platform.https-listener" -}}
{{- $httpsListener := "websecure" -}}
{{- if .Values.traefik.gateway.listeners -}}
  {{- range $name, $listener := .Values.traefik.gateway.listeners -}}
    {{- if eq $listener.protocol "HTTPS" -}}
      {{- $httpsListener = $name -}}
      {{- break -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- $httpsListener -}}
{{- end -}}

{{/*
Get the HTTP listener name (sectionName) from gateway listeners
*/}}
{{- define "lfx-platform.http-listener" -}}
{{- $httpListener := "web" -}}
{{- if .Values.traefik.gateway.listeners -}}
  {{- range $name, $listener := .Values.traefik.gateway.listeners -}}
    {{- if eq $listener.protocol "HTTP" -}}
      {{- $httpListener = $name -}}
      {{- break -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- $httpListener -}}
{{- end -}}

{{/*
Get the default listener (HTTPS if enabled, otherwise HTTP)
*/}}
{{- define "lfx-platform.default-listener" -}}
{{- if eq (include "lfx-platform.https-enabled" .) "true" -}}
{{- include "lfx-platform.https-listener" . -}}
{{- else -}}
{{- include "lfx-platform.http-listener" . -}}
{{- end -}}
{{- end -}}
