<!-- Copyright The Linux Foundation and each contributor to LFX. -->
<!-- SPDX-License-Identifier: MIT -->

# Service Chart Patterns (Canonical)

This file is the canonical implementation guide for service-local Helm charts
in V2 Go services. It lives in `lfx-v2-helm` because the cross-cutting
chart conventions (HTTPRoute, Heimdall RuleSet, ExternalSecret, NATS KV,
probes, env wiring, native-vs-wrapper split) are stable across services and
benefit from a single source of truth. Per-service charts link here from
`docs/service-helm-chart.md` and only document
service-specific facts (path prefixes, KV bucket names, secret refs).

Owner repo for each chart is the service repo itself. `lfx-v2-helm` owns the
shared platform chart at `charts/lfx-platform/` and these cross-service
conventions. `lfx-v2-argocd` owns environment values and image-tag/chart-pin
promotion.

## Native vs wrapper service split

The most important decision is whether the service is **native** (owns its
own NATS-backed data) or a **wrapper** (proxies a third-party API with
credentials in AWS Secrets Manager).

| Trait | Native | Wrapper |
| --- | --- | --- |
| Examples | `project-service`, `committee-service` | `voting-service`, `survey-service`, `mailing-list-service` |
| `nats-kv-buckets.yaml` | yes — owns data | usually no |
| `externalsecret.yaml` + `secretstore.yaml` + `serviceaccount.yaml` (IRSA) | no | yes — fetches third-party credentials from AWS Secrets Manager |
| `externalSecretsOperator.enabled` | `false` | `true` in deployed envs, `false` for local |
| Local dev needs cluster IRSA | no | no — secret block is gated off |

Hybrid services (e.g. some have both KV state and outbound credentials) keep
both template families and toggle them with the same `enabled` flags.

## Chart layout

```text
charts/{service-name}/
├── Chart.yaml
├── values.yaml
└── templates/
    ├── deployment.yaml           # Deployment + env + probes
    ├── service.yaml              # ClusterIP Service
    ├── pdb.yaml                  # PodDisruptionBudget
    ├── httproute.yaml            # Gateway API HTTPRoute (Traefik ingress)
    ├── heimdall-middleware.yaml  # Traefik ForwardAuth (usually disabled per-service)
    ├── ruleset.yaml              # Heimdall RuleSet — one rule per Goa endpoint
    ├── nats-kv-buckets.yaml      # JetStream KV (native services)
    ├── externalsecret.yaml       # AWS Secrets Manager refs (wrapper services)
    ├── secretstore.yaml          # ESO SecretStore (wrapper services)
    └── serviceaccount.yaml       # ServiceAccount + IRSA annotation
```

Some services also include `nats-object-stores.yaml`, `nats-streams.yaml`,
`role.yaml`, `rolebinding.yaml`, or a static `secret.yaml`. Add only what the
service actually needs.

## HTTPRoute

Kubernetes Gateway API `HTTPRoute` tells Traefik which paths route to this
service, and attaches the Heimdall auth middleware as a filter.

```yaml
spec:
  hostnames:
    - "lfx-api.{{ .Values.lfx.domain }}"
  rules:
    - matches:
        - path: { type: Exact, value: /committees }
        - path: { type: PathPrefix, value: /committees/ }
      filters:
        - type: ExtensionRef
          extensionRef:
            group: traefik.io
            kind: Middleware
            name: heimdall-forward-body
      backendRefs:
        - name: {{ .Chart.Name }}
          port: {{ .Values.service.port }}
```

Two middleware variants are available platform-side:

- `heimdall-forward-body` — forwards the request body to Heimdall. Use when
  any RuleSet rule reads from the body (e.g. `project_uid` on a POST).
- `heimdall` — no body forwarding. Use when no rule needs the body.

`heimdall-middleware.yaml` in the service chart is only rendered when
`heimdall.add_middleware: true`. The middleware is usually owned by the
umbrella chart in `lfx-v2-helm`, so per-service the flag is typically `false`.

Update `httproute.yaml` only when the service starts serving a new path
prefix; add a new path entry under `matches`.

## RuleSet for Heimdall (one rule per Goa endpoint)

This is the file edited whenever an endpoint's authorization changes.

```yaml
apiVersion: heimdall.dadrus.github.com/v1alpha4
kind: RuleSet
spec:
  rules:
    - id: "rule:lfx:{service}:{resource}:{action}"
      allow_encoded_slashes: 'off'
      match:
        methods: [GET]
        routes:
          - path: /committees/:uid
      execute:
        - authenticator: oidc
        - authenticator: anonymous_authenticator
        {{- if .Values.app.use_oidc_contextualizer }}
        - contextualizer: oidc_contextualizer
        {{- end }}
        {{- if .Values.openfga.enabled }}
        - authorizer: openfga_check
          config:
            values:
              relation: viewer
              object: "committee:{{ "{{- .Request.URL.Captures.uid -}}" }}"
        {{- else }}
        - authorizer: allow_all
        {{- end }}
        - finalizer: create_jwt
          config:
            values:
              aud: {{ .Values.app.audience }}
```

Choose the relation:

| Operation | Relation |
| --- | --- |
| Read resource | `viewer` |
| Read sensitive data (settings, member list, audit info) | `auditor` |
| Create / Update / Delete | `writer` |
| Self-service (join, accept invite, submit application) | `viewer` |

Source the FGA object from a URL path param (most common):

```yaml
object: "committee:{{ "{{- .Request.URL.Captures.uid -}}" }}"
```

Or from the request body (e.g. POST where parent UID is in the payload):

```yaml
- authorizer: json_content_type   # MUST come before openfga_check when reading body
- authorizer: openfga_check
  config:
    values:
      relation: writer
      object: "project:{{ "{{- .Request.Body.project_uid -}}" }}"
```

Public/anonymous endpoints (e.g. OpenAPI spec) skip `openfga_check` and use
`- authorizer: allow_all`. Health endpoints (`/livez`, `/readyz`) do not need
a rule — they are not routed through Heimdall.

Workflow for a new endpoint:

1. Add it in the Goa design and run `make apigen`.
2. Add a path entry to `httproute.yaml` if it is a new prefix.
3. Add a rule to `ruleset.yaml` with the correct `relation` and `object`.

## NATS JetStream KV (native services)

`nats-kv-buckets.yaml` creates buckets via the `nack` operator:

```yaml
apiVersion: jetstream.nats.io/v1beta2
kind: KeyValue
metadata:
  name: {{ .Values.nats.committees_kv_bucket.name }}
  annotations:
    "helm.sh/resource-policy": keep   # survives helm uninstall — always set this
spec:
  bucket: {{ .Values.nats.committees_kv_bucket.name }}
  history: 20
  storage: file
  maxValueSize: 10485760
  maxBytes: 1073741824
  compression: true
```

Add a new bucket entry (and matching block in `values.yaml`) when the service
stores a new top-level resource type in NATS KV. Always keep
`helm.sh/resource-policy: keep` — losing a KV bucket on `helm uninstall` is
data loss.

## External Secrets (wrapper services)

Wrapper services pull credentials from AWS Secrets Manager via the External
Secrets Operator. Three templates work together:

`serviceaccount.yaml` — ServiceAccount with an IRSA annotation that grants
AWS access:

```yaml
annotations:
  eks.amazonaws.com/role-arn: arn:aws:iam::...
```

`secretstore.yaml` — tells ESO to use AWS Secrets Manager with IRSA auth.

`externalsecret.yaml` — maps remote secret keys to a Kubernetes Secret. The
canonical shape uses `dataFrom` for bulk pulls or per-key `data` entries with
`remoteRef.key` (AWS path) plus optional `remoteRef.property` (JSON field):

```yaml
data:
  - secretKey: ITX_CLIENT_SECRET            # key in the Kubernetes Secret
    remoteRef:
      key: /lfx/voting-service/prod         # path in AWS Secrets Manager
      property: ITX_CLIENT_SECRET           # field within the secret JSON
```

The resulting Kubernetes Secret is named after the chart (`{{ .Chart.Name }}`)
and referenced from `deployment.yaml` via `secretKeyRef`.

The whole mechanism only activates when:

- `externalSecretsOperator.enabled: true`
- `global.awsRegion` is set

Both are off for local dev. Deployed values for these toggles and the
underlying IRSA role ARN live in `lfx-v2-argocd`.

## Deployment env wiring

Every service gets these standard env vars:

| Env var | `values.yaml` key |
| --- | --- |
| `NATS_URL` | `nats.url` |
| `JWKS_URL` | `heimdall.jwksUrl` |
| `JWT_AUDIENCE` | `app.audience` |
| `LOG_LEVEL` | `app.logLevel` |

Plain extra env vars: add directly in `deployment.yaml`:

```yaml
- name: MY_SETTING
  value: {{ .Values.app.mySetting | quote }}
```

Or use `app.extraEnv` in `values.yaml` for ad-hoc injection without touching
the template:

```yaml
app:
  extraEnv:
    - name: FEATURE_FLAG
      value: "true"
```

Secrets sourced from ESO/AWS reference the Kubernetes Secret created by
`externalsecret.yaml`:

```yaml
- name: ITX_CLIENT_SECRET
  valueFrom:
    secretKeyRef:
      name: {{ .Chart.Name }}
      key: ITX_CLIENT_SECRET
```

OpenTelemetry env vars (`OTEL_*`) are conditionally injected from
`app.otel.*`. Their deployed values live in `lfx-v2-argocd` per env.

## Probes

Health probes are pre-wired to `/livez` (liveness) and `/readyz` (readiness
and startup). Do not change these paths from the service chart — they are the
contract the platform expects.

## values.yaml conventions

`values.yaml` holds safe local-dev defaults. Environment-specific overrides
(replica counts, image tags, OTEL config, domain, IRSA ARN, region) live in
`lfx-v2-argocd/values/{env}/{service}.yaml`, not here.

Standard top-level sections every service has:

```yaml
replicaCount: 3
image:
  repository: ghcr.io/linuxfoundation/{service}/{binary}
  tag: ""                  # overridden by ArgoCD at deploy time
openfga:
  enabled: true            # set false only for local dev without FGA
heimdall:
  enabled: true
  add_middleware: false    # middleware usually owned by umbrella chart
externalSecretsOperator:
  enabled: false           # wrapper services only; toggled true in deployed envs
app:
  audience: {service-name} # must match JWT_AUDIENCE and ruleset finalizer aud
  use_oidc_contextualizer: true
  extraEnv: []
  otel: { ... }
```

## Routing recap

| Concern | Owner |
| --- | --- |
| Chart templates, defaults, RuleSet, HTTPRoute, KV bucket names, ExternalSecret shape | Service repo (`charts/<repo>/`) |
| Cross-service chart conventions (this doc), shared platform chart, OpenFGA model | `lfx-v2-helm` |
| Deployed image tags, chart pins, env overrides, IRSA ARN, region, ExternalSecret remote refs in `custom-resources/` | `lfx-v2-argocd` |
| Source secret values, AWS Secrets Manager paths/tags, rotation | DevOps/CloudOps handoff |
