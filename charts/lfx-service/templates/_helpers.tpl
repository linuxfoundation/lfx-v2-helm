{{/*
Copyright The Linux Foundation and each contributor to LFX.
SPDX-License-Identifier: MIT
*/}}

{{/*
Merged labels (standard + chart-wide + resource-specific)
Usage: {{ include "lfx-service.mergedLabels" (dict "context" . "resourceLabels" .Values.service.labels) }}
*/}}
{{- define "lfx-service.mergedLabels" -}}
{{- $standardLabels := dict 
  "app.kubernetes.io/name" .Values.name
  "app.kubernetes.io/instance" .context.Release.Name
  "app.kubernetes.io/managed-by" .context.Release.Service 
  "app.kubernetes.io/version" .Values.image.tag
}}
{{- $commonLabels := .context.Values.commonLabels | default dict }}
{{- $resourceLabels := .resourceLabels | default dict }}
{{- $merged := mergeOverwrite $standardLabels $commonLabels $resourceLabels }}
{{- toYaml $merged }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "lfx-service.selectorLabels" -}}
app.kubernetes.io/name: {{ .Values.name }}
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
