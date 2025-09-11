{{/*
Copyright The Linux Foundation and each contributor to LFX.
SPDX-License-Identifier: MIT
*/}}

{{/*
Expand the name of the chart.
*/}}
{{- define "lfx-service.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "lfx-service.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "lfx-service.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}


{{/*
Merged labels (standard + chart-wide + resource-specific)
Usage: {{ include "lfx-service.mergedLabels" (dict "context" . "resourceLabels" .Values.service.labels) }}
*/}}
{{- define "lfx-service.mergedLabels" -}}
{{- $standardLabels := dict 
  "helm.sh/chart" (include "lfx-service.chart" .context)
  "app.kubernetes.io/name" (include "lfx-service.name" .context)
  "app.kubernetes.io/instance" .context.Release.Name
  "app.kubernetes.io/managed-by" .context.Release.Service 
}}
{{- if .context.Chart.AppVersion }}
{{- $_ := set $standardLabels "app.kubernetes.io/version" .context.Chart.AppVersion }}
{{- end }}
{{- $commonLabels := .context.Values.commonLabels | default dict }}
{{- $resourceLabels := .resourceLabels | default dict }}
{{- $merged := mergeOverwrite $standardLabels $commonLabels $resourceLabels }}
{{- toYaml $merged }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "lfx-service.selectorLabels" -}}
app.kubernetes.io/name: {{ include "lfx-service.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Merged annotations (chart-wide + resource-specific)
Usage: {{ include "lfx-service.mergedAnnotations" (dict "context" . "resourceAnnotations" .Values.service.annotations) }}
*/}}
{{- define "lfx-service.mergedAnnotations" -}}
{{- $commonAnnotations := .context.Values.commonAnnotations | default dict }}
{{- $resourceAnnotations := .resourceAnnotations | default dict }}
{{- $merged := mergeOverwrite $commonAnnotations $resourceAnnotations }}
{{- if $merged }}
{{- toYaml $merged }}
{{- end }}
{{- end }}

{{/*
Get the default hostname for HTTPRoute
*/}}
{{- define "lfx-service.defaultHostname" -}}
{{- printf "lfx-api.%s" .Values.global.domain }}
{{- end }}

{{/*
Generate Heimdall rule execute section
*/}}
{{- define "lfx-service.ruleExecute" -}}
- authenticator: oidc
- authenticator: anonymous_authenticator
{{- if .Values.ruleSet.useOidcContextualizer }}
- contextualizer: oidc_contextualizer
{{- end }}
{{- if .authorization }}
{{- if .Values.ruleSet.openfgaEnabled }}
{{- if .authorization.requireJsonContent }}
- authorizer: json_content_type
{{- end }}
- authorizer: openfga_check
  config:
    values:
      relation: {{ .authorization.relation }}
      object: {{ .authorization.object | quote }}
{{- else }}
# When OpenFGA is disabled, allow all requests
# (Only meant for *local development* because OpenFGA should be enabled when deployed)
- authorizer: allow_all
{{- end }}
{{- else }}
- authorizer: allow_all
{{- end }}
- finalizer: create_jwt
  config:
    values:
      aud: {{ .Values.ruleSet.audience }}
{{- end }}
