# LFX v2 Helm charts

This repository contains Helm charts for deploying the LFX v2 platform on Kubernetes.

> Agents working in this repo should start with [`CLAUDE.md`](CLAUDE.md).
> Platform chart guidance lives in [`docs/platform-chart.md`](docs/platform-chart.md),
> local stack guidance lives in
> [`docs/local-platform-getting-started.md`](docs/local-platform-getting-started.md),
> and service chart conventions live in
> [`docs/service-chart-patterns.md`](docs/service-chart-patterns.md).

## Repository structure

```text
lfx-v2-helm/
└── charts/
    └── lfx-platform/       # Main LFX Platform chart
        ├── templates/      # Kubernetes templates
        ├── Chart.yaml      # Chart metadata
        ├── values.yaml     # Default values
        └── README.md       # Documentation
```

## Installation

See the [lfx-platform chart README](./charts/lfx-platform/README.md) for
installation instructions.

## Components

LFX v2 includes the following infrastructure components:

- **Traefik**: API Gateway and Ingress Controller.
- **OpenFGA**: Fine-Grained Authorization with Relationship-Based Access
  Control (ReBAC).
- **Heimdall**: Access decision service, bridges Traefik to OpenFGA.
- **NATS**: Messaging layer used by LFX v2 resource APIs to communicate with
  each other and with platform components; also provides durable key-value storage.
- **OpenSearch**: Powers platform global search and audit log capabilities.

Building on those, custom platform components provide shared services essential
to the LFX v2 platform:

- **[indexer](https://github.com/linuxfoundation/lfx-v2-indexer-service)**:
  Processes messages from resource APIs to keep OpenSearch in sync
  with data changes, and propagates data events to the rest of the platform.
- **[fga-sync](https://github.com/linuxfoundation/lfx-v2-fga-sync)**: Processes
  messages from resource APIs to keep OpenFGA relationships in sync with data
  changes, and acts as a caching proxy for serving OpenFGA bulk access-check
  requests in the platform.
- **[query-svc](https://github.com/linuxfoundation/lfx-v2-query-service)**:
  HTTP service for LFX API consumers to perform
  access-controlled queries for LFX resources, including typeahead and
  full-text search.
- **[access-check](https://github.com/linuxfoundation/lfx-v2-access-check)**:
  HTTP service for LFX API consumers to perform bulk access checks for
  resources.

Key LFX resource APIs are forthcoming, which can be optionally enabled with this chart.

## Component diagram

```mermaid
flowchart TD
    Traefik(Traefik Ingress)
    OpenSearch[(OpenSearch)]
    OpenFGA(OpenFGA)
    Heimdall{Heimdall}

    subgraph NATS
        nats-access-check-subject@{ shape: braces, label: "access-check & replies" }
        nats-update-access-subject@{ shape: braces, label: "update-access & ACK" }
        nats-update-index-subject@{ shape: braces, label: "index data & ACK" }
        nats-kv-data@{ shape: braces, label: "Jetstream<br />KV buckets" }
    end

    Traefik -->|allow/deny?| Heimdall
    Heimdall -->|decision| Traefik
    Heimdall -->|check relations based on URL pattern rulesets| OpenFGA

    Traefik --->|user queries| query-svc
    query-svc --> OpenSearch

    access-check[<em>access-check</em>]
    Traefik --->|user access checks| access-check
    access-check <-.-> nats-access-check-subject

    resource-apis@{ shape: processes, label: "Resource APIs<br />(projects, committees, etc)"}
    Traefik -->|Heimdall-authorized user requests| resource-apis

    query-svc[<em>query-svc</em>]
    query-svc <-.->|filter search results| nats-access-check-subject

    nats-access-check-subject <-.->|bulk access checks and responses| fga-sync
    nats-update-access-subject <-.->|access updates & ACK| fga-sync

    fga-sync[<em>fga-sync</em>]
    fga-sync <-->|access updates, bulk access checks| OpenFGA

    indexer[<em>indexer</em>]
    nats-update-index-subject <-.->|index data & ACK| indexer
    indexer <-->|index/revision resources| OpenSearch

    resource-apis <-..-> nats-update-access-subject
    resource-apis <-.-> nats-update-index-subject
    resource-apis <-.->|data storage| nats-kv-data
```

## Configuration

See the [lfx-platform chart README](./charts/lfx-platform/README.md) for configuration options and examples.

## Releases

This repository automatically publishes Helm charts to GitHub Container Registry (GHCR) when tags are created.

### Creating a Release

1. Do not manually bump `charts/lfx-platform/Chart.yaml` `version`; the chart
   build job dynamically replaces it with the release version. Update service
   subchart version constraints in `Chart.yaml` and regenerate `Chart.lock`
   only when dependency pins change.
2. After the pull request is merged, create a GitHub release and choose the
   option for GitHub to also tag the repository. The tag must match the `v*`
   pattern (for example, `v0.0.2`); the release workflow only runs for pushed
   tags matching `v*` (see `.github/workflows/release.yaml`). The release tag
   is the chart release version used by the packaging workflow.
3. The GitHub Actions workflow will automatically:
   - Package the Helm chart
   - Publish it to `ghcr.io/linuxfoundation/lfx-v2-helm/chart`
   - Sign the chart with cosign for security
   - Generate SLSA provenance attestation

## Development

To contribute to this repository:

1. Fork the repository
2. Commit your changes to a feature branch in your fork. Ensure your commits
   are signed with the [Developer Certificate of Origin
   (DCO)](https://developercertificate.org/).
   You can use the `git commit -s` command to sign your commits.
3. If you changed a service dependency, ensure `charts/lfx-platform/Chart.yaml`
   and `charts/lfx-platform/Chart.lock` agree after running
   `helm dependency update charts/lfx-platform`.
4. If you are adding a new platform component, ensure it is documented in the
   [component diagram](#component-diagram) and the README.
5. Run MegaLinter locally at the root of the working directory to check for
   errors or linting problems:
   ```bash
   docker run --rm --platform linux/amd64 \
     -v "$(pwd):/tmp/lint:rw" \
     oxsecurity/megalinter-documentation:v8
   ```
6. Submit your pull request

## License

Copyright The Linux Foundation and each contributor to LFX.

This project’s source code is licensed under the MIT License. A copy of the
license is available in `LICENSE`.

This project’s documentation is licensed under the Creative Commons Attribution
4.0 International License \(CC-BY-4.0\). A copy of the license is available in
`LICENSE-docs`.
