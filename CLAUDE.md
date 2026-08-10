# CLAUDE.md

This repository owns the shared LFX V2 platform Helm chart and local platform
stack. It is not the owner for service-specific application logic.

> **Central LFX skills:**
> - Start with `/lfx-skills:lfx` for cross-repo tasks, "where does X live" questions, owner/peer repo routing, or missing checkouts.
> - Use `/lfx-skills:lfx-platform-architecture` after routing when you need platform composition or write/read/access-check flows across FGA, indexer, query, Heimdall, OpenFGA, Helm, or ArgoCD.
> - Use `/lfx-skills:lfx-platform-architecture` for service classes and service-chart handoff boundaries. Go coding conventions live in each service repo's path-scoped `<short-repo-name>-dev` skill.
> - Repo-owned docs under `docs/` are canonical for platform chart, OpenFGA model, service chart conventions, and local stack guidance. If the plugin is missing, install with `/plugin marketplace add linuxfoundation/lfx-skills` then `/plugin install lfx-skills@lfx-skills`.

## Repository Ownership

- `charts/lfx-platform/` - shared platform chart composition and dependencies.
- OpenFGA model template under `charts/lfx-platform/templates/openfga/`.
- Local platform stack defaults for NATS, OpenSearch, OpenFGA, Traefik,
  Heimdall, Gateway API, and related shared infrastructure.
- `PERMISSIONS.md` generated from OpenFGA annotations.

Service/app repos own their own `charts/<service-or-app>/` templates and
defaults. `lfx-v2-argocd` owns deployed environment values, chart pins, image
tags, ApplicationSets, previews, custom resources, and promotion.

## Agent Guidance

The repo-local `/helm-local-stack` skill (under `.claude/skills/`) is the
guided entry point for bringing up the local platform stack, editing the
OpenFGA model and re-rendering permissions docs, updating platform chart
dependencies, and debugging local stack install/sync issues. Prefer it over
reinventing commands.

Repo-owned implementation guidance lives under `docs/`:

- `docs/platform-chart.md` - composition of
  `charts/lfx-platform`, subchart list, OpenFGA model edit workflow,
  `helm dependency update` failure modes, and worked examples.
- `docs/local-platform-getting-started.md` - bringing the
  shared platform stack up locally (commands, secrets, gotchas).
- `docs/service-chart-patterns.md` - canonical cross-service
  chart conventions (HTTPRoute, Heimdall RuleSet, ExternalSecret, NATS KV,
  probes, env wiring, native vs wrapper). Per-service repos link here from
  their own `docs/service-helm-chart.md` stubs.

Existing agent skills under `.agents/skills/` remain the source for OpenFGA
documentation maintenance:

- `populate-jtbds` - refresh `@fgadoc:jtbd` annotations from live API rules.
- `render-permissions` - render `PERMISSIONS.md` from model annotations.

## Consumed Cross-Repo Contracts

This repo depends on contracts owned elsewhere. Do not copy or infer them from
local examples. Read the owner file before changing platform model
coordination, service chart handoffs, or deployed-value assumptions.

- Deployed environment values, chart pins, image tags, ApplicationSets, and
  ExternalSecret references:
  `lfx-v2-argocd/docs/`
- Service-local chart templates and defaults:
  `<service-repo>/charts/<service-name>/`
- Generic FGA envelope and access-check contract:
  `lfx-v2-fga-sync/docs/fga-sync-contract.md`
- Generic indexer event contract:
  `lfx-v2-indexer-service/docs/indexer-contract.md`

Use `/lfx-skills:lfx` if an owner repo is missing locally, the path has moved,
or the task needs additional peer repos.

## Validation

Before changing chart templates or the OpenFGA model, read the relevant
`charts/lfx-platform/README.md`, `docs/openfga.md`, and `PERMISSIONS.md`
sections. Prefer the repo's existing Makefile/workflow documentation when
available; do not invent Helm or cluster commands from central guidance.
