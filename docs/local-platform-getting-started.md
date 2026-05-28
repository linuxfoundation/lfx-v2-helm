<!-- Copyright The Linux Foundation and each contributor to LFX. -->
<!-- SPDX-License-Identifier: MIT -->

# Local Platform Bring-Up

This file is for bringing the shared LFX V2 platform stack up locally. For
the chart composition itself see `platform-chart.md`. For the cross-service
chart patterns see `service-chart-patterns.md`.

## What is bundled

Subcharts in `charts/lfx-platform/`:

- `traefik` (Gateway API ingress)
- `openfga` + `fga-operator`
- `heimdall` (auth/authz middleware)
- `nats` + `nack` (JetStream + KV operator)
- `opensearch`
- `mailpit`, `authelia` (local-only auth surface)
- `external-secrets` (operator; ExternalSecret CRs live in service charts and
  in `lfx-v2-argocd/custom-resources/`)
- `cert-manager` + `trust-manager`
- LFX service subcharts pinned to OCI versions
  (`lfx-v2-project-service`, `lfx-v2-committee-service`,
  `lfx-v2-meeting-service`, etc.) — see `Chart.yaml` for the current list

## Bring-up flow

```bash
helm dependency update charts/lfx-platform
cp charts/lfx-platform/values.local.example.yaml charts/lfx-platform/values.local.yaml
# fill in local secret values per the chart README and the team 1Password vault
helm install -n lfx lfx-platform ./charts/lfx-platform --values charts/lfx-platform/values.local.yaml
```

Some subcharts (e.g. `lfx-v2-voting-service`) require Kubernetes Secrets to
exist in the namespace **before** install — see
`charts/lfx-platform/README.md` for the per-subchart secret-creation list and
the 1Password vault note "LFX Platform Chart Values Secrets - Local
Development".

## OpenFGA model

The shared OpenFGA authorization model lives at:

```text
charts/lfx-platform/templates/openfga/model.yaml
```

After changing it, regenerate `PERMISSIONS.md` via the existing agent skill:

```text
.agents/skills/render-permissions/SKILL.md
```

See `platform-chart.md` for the worked example of editing the model and
re-rendering the docs.

## When to touch this repo

| Task | Touch this repo? |
| --- | --- |
| Change shared platform dependency config | Yes |
| Change the OpenFGA model | Yes |
| Add a new platform-level subchart | Yes |
| Change a service route, env var, deployment, or RuleSet | No, start in the service repo |
| Change deployed values for dev/staging/prod | No, use `lfx-v2-argocd` |
| Load fixture data | No, use `lfx-v2-mockdata` |

For the cross-repo ownership statement see
`/lfx-skills:lfx` and its `deployment-routing.md` reference.
Do not restate it here.

## Review checks

- Confirm the change is shared platform behavior, not service-local behavior.
- Keep local values examples aligned with chart defaults.
- Re-render or update OpenFGA permission docs when the model changes.
- Do not embed real secrets in local values examples.
