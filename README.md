# LFX v2 helm charts

This repository contains Helm charts for deploying the LFX v2 platform on Kubernetes.

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

To install the LFX Platform chart:

```bash
# Add required Helm repositories
helm repo add traefik https://traefik.github.io/charts
helm repo add dadrus https://dadrus.github.io/heimdall/charts
helm repo add jouve https://jouve.github.io/charts/
helm repo add nats https://nats-io.github.io/k8s/helm/charts/
helm repo add openfga https://openfga.github.io/helm-charts
helm repo add opensearch https://opensearch-project.github.io/helm-charts/
helm repo update

# Create namespace
kubectl create namespace lfx

# Install the chart
helm install lfx-platform ./charts/lfx-platform -n lfx -f charts/lfx-platform/values.yaml
```

## Components

LFX v2 includes the following infrastructure components:

- **Traefik**: API Gateway and Ingress Controller.
- **OpenFGA**: Fine-Grained Authorization with Relationship-Based Access
  Control (ReBAC).
- **Heimdall**: Access decision service, bridges Traefik to OpenFGA.
- **NATS**: Messaging layer used by LFX v2 resource APIs to communicate with
  each other and with platform components.
- **OpenSearch**: Powers platform global search and audit log capabilities.

Building on those, custom platform components provide shared services essential
to the LFX v2 platform:

- **indexer**: Processes messages from resource APIs to keep OpenSearch in sync
  with data changes, and propagates data events to the rest of the platform.
- **fga-sync**: Processes messages from resource APIs to keep OpenFGA
  relationships in sync with data changes, and acts as a caching proxy for
  serving OpenFGA bulk access-check requests in the platform.
- **query-svc**: HTTP service for LFX API consumers to perform
  access-controlled queries for LFX resources, including typeahead and
  full-text search.
- **access-check**: HTTP service for LFX API consumers to perform bulk access
  checks for resources.

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

## Development

To contribute to this repository:

1. Fork the repository
2. Make your changes
3. Submit a pull request

## License

Copyright The Linux Foundation and each contributor to LFX.

This project’s source code is licensed under the MIT License. A copy of the
license is available in `LICENSE`.

This project’s documentation is licensed under the Creative Commons Attribution
4.0 International License \(CC-BY-4.0\). A copy of the license is available in
`LICENSE-docs`.
