---
name: helm-local-stack
description: Use when the user wants to bring up the local LFX platform stack, edit the OpenFGA authorization model and re-render permissions docs, update platform chart dependencies, or debug local stack install/sync issues. Fires on "bring up local LFX platform", "edit OpenFGA model", "update platform chart dependencies", "debug local stack".
---

# helm-local-stack

Guided workflow for the shared LFX V2 platform Helm chart and its local
stack. This repo owns `charts/lfx-platform/`, the OpenFGA model, and the
cross-service chart conventions consumed from `service-chart-patterns.md`.
Service-local charts live in each service repo; deployed env state lives
in `lfx-v2-argocd`.

## Common tasks

| Task | See |
| --- | --- |
| First-time local bring-up | `docs/local-platform-getting-started.md` |
| Edit the OpenFGA model + re-render `PERMISSIONS.md` | `docs/platform-chart.md` + `.agents/skills/render-permissions/SKILL.md` |
| Update / bump platform subchart dependencies | `docs/platform-chart.md` |
| Debug `helm dependency update` failures | `docs/platform-chart.md` "Failure modes" |
| Reference cross-service chart conventions (HTTPRoute, RuleSet, NATS KV, ExternalSecret) | `docs/service-chart-patterns.md` |

## Workflow

1. **Bring up locally:**

   ```bash
   helm dependency update charts/lfx-platform
   cp charts/lfx-platform/values.local.example.yaml charts/lfx-platform/values.local.yaml
   # fill in local secrets per chart README + 1Password "LFX V2" vault
   helm install -n lfx lfx-platform ./charts/lfx-platform --values charts/lfx-platform/values.local.yaml
   ```

   See `charts/lfx-platform/README.md` for the per-subchart secret-creation
   list (e.g. `lfx-v2-voting-service` requires its Secret to exist before
   install).

2. **Edit the OpenFGA model:**
   - Edit `charts/lfx-platform/templates/openfga/model.yaml`.
   - Update `@fgadoc:jtbd` annotations on changed/new relations.
   - Run `.agents/skills/render-permissions/SKILL.md` to regenerate
     `PERMISSIONS.md`.
   - If a relation rename or new relation affects a service, coordinate
     with the owning service repo's RuleSet and with `lfx-v2-fga-sync` /
     `lfx-v2-query-service` per `platform-chart.md`.

3. **Update platform chart deps:**
   - Edit version constraints in `charts/lfx-platform/Chart.yaml`.
   - Run `helm dependency update charts/lfx-platform`.
   - Commit `Chart.yaml` and `Chart.lock`.
   - Local install picks up automatically; deployed envs need a matching
     `targetRevision:` bump in `lfx-v2-argocd`.

4. **Debug:**
   - `helm template lfx-platform charts/lfx-platform --values charts/lfx-platform/values.local.yaml | less`
   - `helm lint charts/lfx-platform`
   - For `oci://` pull errors: `helm registry login ghcr.io` first.
   - See `platform-chart.md` "Failure modes" for common pitfalls.

## Boundaries

- Do not embed service-local templates in `charts/lfx-platform/` — those
  belong in the owning service repo's `charts/<service>/`.
- Do not deploy environment overrides from here — that is `lfx-v2-argocd`.
- For the cross-repo three-way split see
  `/lfx-skills:lfx` and its deployment routing reference.

## References

- `docs/local-platform-getting-started.md`
- `docs/platform-chart.md`
- `docs/service-chart-patterns.md`
- `.agents/skills/render-permissions/SKILL.md`
- `.agents/skills/populate-jtbds/SKILL.md`
