# Copyright The Linux Foundation and each contributor to LFX.
# SPDX-License-Identifier: MIT
---
# LFX CRDs Chart

Operator and CRD-providing charts for the LFX v2 platform, kept in a
separate chart from `charts/lfx-platform` so their CRDs can be established
before the umbrella chart's own resources (for example its CloudNativePG
`Cluster`) are rendered. Helm's built-in `crds/`-directory handling (install
first, wait for the CRD to be established) does not apply to the pinned
`cloudnative-pg` dependency (`~0.29.0`): that chart defines its CRDs as
regular templates under `templates/crds/`, not in a `crds/` directory, so
Helm treats them like any other templated resource and does not wait for
them to be established before returning. That is why this operator must be
installed standalone, ahead of `lfx-platform`, rather than relying on
Helm's dependency-CRD ordering.

**Local development only.** Deployed environments (dev/staging/prod) do
not install this chart -- see `docs/platform-chart.md`.

**Kubernetes 1.29+ required.** The pinned `cloudnative-pg` dependency
(`~0.29.0`) declares `kubeVersion: ">=1.29.0-0"`; that requirement is
propagated to this chart's own `Chart.yaml` so `helm install` fails fast on
an unsupported cluster instead of erroring later.

## Installing

```bash
kubectl create namespace lfx  # if not already created

helm dependency update charts/lfx-crds
# --wait ensures the operator Deployment (and its admission webhooks) is
# ready before you install lfx-platform, whose CloudNativePG Cluster
# resource depends on it.
helm install -n lfx lfx-crds ./charts/lfx-crds --wait
```

Then bring up `charts/lfx-platform` as usual (its CloudNativePG `Cluster`
resource assumes the operator installed here already exists).

## What this chart contains

| Group            | Provides                                            | Toggle                     |
|-------------------|------------------------------------------------------|-----------------------------|
| `cloudnative-pg`  | The CloudNativePG operator and its CRDs (`postgresql.cnpg.io/*`). | `cloudnative-pg.enabled` |

Additional operator/CRD groups may be added here over time, following the
same one-group-per-dependency, `<group>.enabled` pattern.
