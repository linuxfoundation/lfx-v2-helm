# Copyright The Linux Foundation and each contributor to LFX.
# SPDX-License-Identifier: MIT
---
# LFX CRDs Chart

Operator and CRD-providing charts for the LFX v2 platform, kept in a
separate chart from `charts/lfx-platform` so their CRDs can be established
before the umbrella chart's own resources (for example its CloudNativePG
`Cluster`) are rendered. Helm cannot install CRDs from a chart dependency
and then immediately render a CR from that same `helm install` in one
shot, so this chart must be installed first, standalone.

**Local development only.** Deployed environments (dev/staging/prod) do
not install this chart -- see `docs/platform-chart.md`.

## Installing

```bash
kubectl create namespace lfx  # if not already created

helm dependency update charts/lfx-crds
helm install -n lfx lfx-crds ./charts/lfx-crds
```

Then bring up `charts/lfx-platform` as usual (its CloudNativePG `Cluster`
resource assumes the operator installed here already exists).

## What this chart contains

| Group            | Provides                                            | Toggle                     |
|-------------------|------------------------------------------------------|-----------------------------|
| `cloudnative-pg`  | The CloudNativePG operator and its CRDs (`postgresql.cnpg.io/*`). | `cloudnative-pg.enabled` |

Additional operator/CRD groups may be added here over time, following the
same one-group-per-dependency, `<group>.enabled` pattern.
