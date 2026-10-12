{{- /*
Copyright The Linux Foundation and each contributor to LFX.
SPDX-License-Identifier: MIT
*/ -}}

{{/*
Render the NATS server `authorization` block from `nats.lfxAuthorization`.

This is included from `nats.config.merge` via the nats chart's
`$tplYamlSpread`, so it runs in the nats subchart's context: `.Values` here is
the `nats:` values block, not the platform chart's root values.

Model:
- Clients that connect without credentials are mapped to the
  `anonymousUser` (NATS `no_auth_user`). They keep full subscribe rights and
  can publish everywhere except the subjects of every enabled
  `restrictedPublish` rule.
- Each entry in `users` is an nkey user. It can publish everywhere except the
  subjects of enabled rules that do not list it in `publishers`.

Renders nothing when `lfxAuthorization.enabled` is false, which leaves the bus
with no authorization at all (the historical default).
*/}}
{{- define "lfx-platform.nats.authorization" -}}
{{- $authz := .Values.lfxAuthorization | default dict -}}
{{- if $authz.enabled -}}
{{- $users := $authz.users | default dict -}}
{{- $rules := list -}}
{{- range $ruleName, $rule := ($authz.restrictedPublish | default dict) -}}
{{- if $rule.enabled -}}
{{- if not $rule.subjects -}}
{{- fail (printf "nats.lfxAuthorization.restrictedPublish.%s: subjects must not be empty" $ruleName) -}}
{{- end -}}
{{- range $publisher := ($rule.publishers | default list) -}}
{{- if not (hasKey $users $publisher) -}}
{{- fail (printf "nats.lfxAuthorization.restrictedPublish.%s: publisher %q is not defined in nats.lfxAuthorization.users" $ruleName $publisher) -}}
{{- end -}}
{{- end -}}
{{- $rules = append $rules $rule -}}
{{- end -}}
{{- end -}}
{{- $anonDeny := list -}}
{{- range $rule := $rules -}}
{{- $anonDeny = concat $anonDeny $rule.subjects -}}
{{- end -}}
{{- $anonPerms := dict "subscribe" (dict "allow" (list ">")) -}}
{{- if $anonDeny -}}
{{- $_ := set $anonPerms "publish" (dict "allow" (list ">") "deny" (uniq $anonDeny)) -}}
{{- end -}}
{{- $anonymousUser := required "nats.lfxAuthorization.anonymousUser is required" $authz.anonymousUser -}}
{{- $userEntries := list (dict "user" $anonymousUser "permissions" $anonPerms) -}}
{{- range $userName, $user := $users -}}
{{- if $user.nkey -}}
{{- if not (hasPrefix "U" $user.nkey) -}}
{{- fail (printf "nats.lfxAuthorization.users.%s.nkey must be a user public nkey (starts with U), never a seed" $userName) -}}
{{- end -}}
{{- $deny := list -}}
{{- range $rule := $rules -}}
{{- if not (has $userName ($rule.publishers | default list)) -}}
{{- $deny = concat $deny $rule.subjects -}}
{{- end -}}
{{- end -}}
{{- $perms := dict "subscribe" (dict "allow" (list ">")) -}}
{{- if $deny -}}
{{- $_ := set $perms "publish" (dict "allow" (list ">") "deny" (uniq $deny)) -}}
{{- end -}}
{{- $userEntries = append $userEntries (dict "nkey" $user.nkey "permissions" $perms) -}}
{{- end -}}
{{- end -}}
authorization:
  users:
    {{- toYaml $userEntries | nindent 4 }}
no_auth_user: {{ $anonymousUser | quote }}
{{- end -}}
{{- end -}}
