<!-- Copyright The Linux Foundation and each contributor to LFX. -->
<!-- SPDX-License-Identifier: MIT -->

# Platform Chart (`charts/lfx-platform`)

This file documents the platform/umbrella chart composition that this repo
owns. For local bring-up commands see `local-platform-getting-started.md`.
For service-local chart conventions see `service-chart-patterns.md`.

## Chart composition

`charts/lfx-platform/` is an umbrella chart that aggregates platform
infrastructure subcharts and pins LFX service subcharts to their OCI chart
versions. See `Chart.yaml` for the authoritative list. As of writing it
includes:

- Infrastructure subcharts:
  - `traefik` (Gateway API ingress)
  - `openfga` + `fga-operator`
  - `heimdall` (auth/authz middleware)
  - `nats` + `nack` (JetStream + KV operator)
  - `opensearch`
  - `mailpit`, `authelia` (local-only auth surface)
  - `external-secrets`
  - `cert-manager` + `trust-manager`
- LFX service subcharts pinned to GHCR OCI versions:
  - `lfx-v2-query-service`
  - `lfx-v2-project-service`
  - `lfx-v2-fga-sync`
  - `lfx-v2-access-check`
  - `lfx-v2-indexer-service`
  - `lfx-v2-committee-service`
  - `lfx-v2-meeting-service`
  - `lfx-v2-mailing-list-service`
  - `lfx-v2-auth-service`
  - `lfx-v2-voting-service`
  - `lfx-v2-survey-service`

Service subchart versions in `Chart.yaml` are platform-side **defaults**.
Deployed dev/staging/prod chart pins are owned by `lfx-v2-argocd`'s
ApplicationSets, not by this chart.

## Repo-owned templates

This repo also ships templates rendered directly by the umbrella chart:

```text
charts/lfx-platform/templates/
├── openfga/
│   ├── model.yaml          # Shared OpenFGA authorization model
│   └── db-secrets.yaml
├── heimdall/               # Shared Heimdall RuleSet / middleware
├── authelia/               # Local-only auth
├── mailpit/                # Local-only email capture
├── swagger_ui/             # Aggregated OpenAPI viewer
└── whoami/                 # Diagnostic
```

The OpenFGA model is the single most important shared template: every
service's RuleSet `openfga_check` calls authorize against the types,
relations, and inheritance defined in
`charts/lfx-platform/templates/openfga/model.yaml`.

## OpenFGA model: worked edit

Scenario: add a new relation `auditor` to type `committee`.

1. Edit `charts/lfx-platform/templates/openfga/model.yaml` and add the
   relation (including any inheritance from `project` per the existing
   convention).
2. Update `@fgadoc:jtbd` annotations on the new relation so the rendered
   permissions table reflects the actual job-to-be-done.
3. Re-render `PERMISSIONS.md`:

   ```bash
   # follow .agents/skills/render-permissions/SKILL.md
   ```

4. If a service emits or consumes this relation, update that service's
   `ruleset.yaml` (`object: "committee:..."` + `relation: auditor`) and its
   FGA-sync message shape. Coordinate with `lfx-v2-fga-sync` if the generic
   handler expectations change, and with `lfx-v2-query-service` if
   query-time filtering changes.
5. Re-run `helm dependency update charts/lfx-platform` only if a subchart
   version changed — model edits alone do not require it.

## `helm dependency update` failure modes

Common failures and how to read them:

- **`Error: no repository definition for ...`** — a subchart repo isn't
  registered in your local Helm config. Either add it with `helm repo add`
  using the URL from `Chart.yaml`, or rely on the OCI/HTTPS URLs already
  inlined in dependency `repository:` entries (Helm 3.8+ supports both).
- **`failed to download ... from oci://`** — usually a transient registry
  blip or, for private images, missing `helm registry login ghcr.io`. Retry
  after login.
- **`version "~X.Y.Z" not found`** — the subchart was yanked or the upstream
  range no longer matches. Bump the constraint in `Chart.yaml` and re-run.
- **`Chart.lock` drift** — if multiple developers run `dependency update`
  in parallel and commit lock files, expect merge conflicts. Resolve by
  re-running `helm dependency update charts/lfx-platform` and committing
  the regenerated `Chart.lock`.
- **Service subchart not pulling** — check the `condition:` flag in
  `Chart.yaml` against `values.yaml` / your local override. If `enabled`
  is false the subchart is skipped silently.

## Worked example: editing a service-subchart pin

Scenario: bump the platform's default `lfx-v2-meeting-service` chart pin
from `~0.8.0` to `~0.9.0`.

1. Edit `charts/lfx-platform/Chart.yaml`:

   ```yaml
   - name: lfx-v2-meeting-service
     repository: oci://ghcr.io/linuxfoundation/lfx-v2-meeting-service/chart
     version: ~0.9.0
     condition: lfx-v2-meeting-service.enabled
   ```

2. Run `helm dependency update charts/lfx-platform`. Confirm `Chart.lock`
   updates and `charts/lfx-platform/charts/lfx-v2-meeting-service-*.tgz`
   refreshes.
3. Re-test local install per `local-platform-getting-started.md`.
4. If staging/prod should follow, open a matching PR in `lfx-v2-argocd` to
   bump the chart pin in `apps/<env>/lfx-v2-applications.yaml`. This repo
   only changes the local/default; deployed environments are not affected
   by `Chart.yaml` changes alone.

## Validation commands

Use the repo's existing Makefile / workflow docs as the source of truth.
Common quick checks:

```bash
helm dependency update charts/lfx-platform
helm template lfx-platform charts/lfx-platform --values charts/lfx-platform/values.local.yaml | less
helm lint charts/lfx-platform
```

Do not invent additional Helm or cluster commands from central guidance.

## Boundary

This repo owns the shared platform chart and the shared OpenFGA model.
Service-local routes, env vars, probes, RuleSets, KV buckets, and
ExternalSecret template shape stay in the owning service repo. Deployed
environment values, chart pins, image tags, and ApplicationSets stay in
`lfx-v2-argocd`. See
`/lfx-skills:lfx` and its `deployment-routing.md` reference
for the cross-repo split.
