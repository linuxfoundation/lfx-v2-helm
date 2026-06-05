# LFX platform umbrella Helm chart

This Helm chart deploys infrastructure components, platform services, and key
resource APIs for the LFX platform.

## Prerequisites

- Kubernetes 1.19+
- Helm 3.2.0+
- PV provisioner support in the underlying infrastructure (if persistence is
  enabled)

## Installing the chart

First, create the namespace (recommended):

```bash
kubectl create namespace lfx
```

### Installing via the OCI registry

```bash
# Install the latest version of the chart.
helm install -n lfx lfx-platform \
  oci://ghcr.io/linuxfoundation/lfx-v2-helm/chart/lfx-platform
```

For reproducible installs or when debugging a specific release, pin the version
with `--version`:

```bash
helm install -n lfx lfx-platform \
  oci://ghcr.io/linuxfoundation/lfx-v2-helm/chart/lfx-platform \
  --version <version>
```

### Installing from source

Clone the repository before running the following commands from the root of the
working directory.

```bash
# Pull down chart dependencies.
helm dependency update charts/lfx-platform

# Install the chart.
helm install -n lfx lfx-platform \
    ./charts/lfx-platform
```

### Customizing local development values

The default `values.yaml` is configured for local development. To override
specific values for your own environment without committing them, copy the
bundled example file:

```bash
cp charts/lfx-platform/values.local.example.yaml charts/lfx-platform/values.local.yaml
```

`values.local.yaml` is gitignored, so you can freely modify it. Pass it when
installing from OCI or from source:

```bash
# From OCI registry
helm install -n lfx lfx-platform \
  oci://ghcr.io/linuxfoundation/lfx-v2-helm/chart/lfx-platform \
  --values charts/lfx-platform/values.local.yaml

# From source
helm install -n lfx lfx-platform ./charts/lfx-platform \
  --values charts/lfx-platform/values.local.yaml
```

Later `--values` files take precedence over earlier ones, so you can also layer
additional overrides on top:

```bash
helm install -n lfx lfx-platform \
  oci://ghcr.io/linuxfoundation/lfx-v2-helm/chart/lfx-platform \
  --values charts/lfx-platform/values.local.yaml \
  --values my-overrides.yaml
```

Refer to the [Configuration](#configuration) section and the inline comments
in `values.yaml` for all available parameters.

## Uninstalling the chart

To uninstall/delete the `lfx-platform` deployment:

```bash
helm uninstall lfx-platform -n lfx
# Optional: delete the namespace to delete any persistent resources.
kubectl delete namespace lfx
```

## Configuration

You can override any value in your `values.local.yaml` or by using `--set`
when installing the chart. The canonical reference for all available parameters
is the inline comments in [`values.yaml`](values.yaml).

### Global parameters

| Parameter              | Description                     | Default           |
|------------------------|---------------------------------|-------------------|
| `lfx.domain`           | Domain for services             | `k8s.orb.local`   |
| `lfx.image.registry`   | Global Docker image registry    | `linuxfoundation` |
| `lfx.image.pullPolicy` | Global Docker image pull policy | `IfNotPresent`    |

### Subcharts

Each subchart can be enabled or disabled via its `enabled` key in
[`values.yaml`](values.yaml). The exception is `trust-manager`, which is toggled
via the top-level `trustManagerEnabled` key (see the infrastructure table below).
Refer to the linked documentation for the full set of configuration options.

Default `enabled` values in [`values.yaml`](values.yaml) target local
development. In deployed environments, most LFX service subcharts are disabled
in the umbrella chart via
`lfx-v2-argocd/values/global/lfx-platform.yaml` and deployed as separate
ArgoCD applications instead.

#### Infrastructure subcharts

| Subchart       | Key             | Enabled by default | Description | Documentation |
|----------------|-----------------|-------------------|-------------|---------------|
| Traefik        | `traefik`       | `true`            | Reverse proxy and ingress controller that routes external requests to platform services and enforces Heimdall's auth decisions. | [Traefik Helm Chart](https://github.com/traefik/traefik-helm-chart) |
| OpenFGA        | `openfga`       | `true`            | Fine-grained authorization store implementing relationship-based access control (ReBAC) for the platform. | [OpenFGA Helm Chart](https://github.com/openfga/helm-charts) · [Local docs](../../docs/openfga.md) |
| Heimdall       | `heimdall`      | `true`            | Access decision service that bridges Traefik to OpenFGA, enforcing per-request authorization based on URL pattern rulesets. | [Heimdall Helm Chart](https://github.com/dadrus/heimdall/tree/main/charts/heimdall) |
| NATS           | `nats`          | `true`            | Distributed messaging system providing pub/sub, request/reply, and durable JetStream key-value storage used across all platform and resource services. | [NATS Helm Chart](https://github.com/nats-io/k8s/tree/main/helm/charts/nats) |
| NACK           | `nack`          | `true`            | Kubernetes controller that manages NATS JetStream resources (streams, consumers, key-value buckets) declaratively via CRDs. | [NACK documentation](https://github.com/nats-io/k8s/tree/main/helm/charts/nack) |
| OpenSearch     | `opensearch`    | `true`            | Search and analytics engine that powers platform-wide full-text search and audit log capabilities. | [OpenSearch Helm Chart](https://github.com/opensearch-project/helm-charts) |
| Authelia       | `authelia`      | `true`            | Open-source authentication server providing SSO and MFA for local development (replaces Auth0 in local environments). | [Authelia documentation](https://github.com/authelia/chartrepo/tree/master/charts/authelia) |
| Mailpit        | `mailpit`       | `true`            | Local email testing tool that captures outbound emails for inspection during development without sending them externally. | [Mailpit documentation](https://github.com/jouve/charts/tree/main/charts/mailpit) |
| External Secrets Operator | `external-secrets` | `false` | Kubernetes operator that syncs secrets from external vaults (e.g. AWS Secrets Manager) into Kubernetes secrets. | [External Secrets Helm Chart](https://external-secrets.io/latest/introduction/getting-started/) |
| cert-manager   | `cert-manager`  | `false`           | Kubernetes certificate manager that automates TLS certificate provisioning and renewal. | [cert-manager Helm Chart](https://cert-manager.io/docs/installation/helm/) |
| trust-manager  | `trustManagerEnabled` | `false` | cert-manager companion controller that distributes trust bundles to workloads across namespaces. | [trust-manager Helm Chart](https://cert-manager.io/docs/trust/trust-manager/) |
| fga-operator   | `fga-operator`  | `true`            | Kubernetes operator that manages OpenFGA authorization models and store configuration declaratively via CRDs. | — |

#### LFX platform service subcharts

Platform services are integral to the platform as a whole and are resource
data-agnostic — they operate independently of any particular domain and are
consumed by resource services. For example, the indexer service can index any
kind of data from any resource service, and the access-check service enforces
permissions regardless of what resource is being accessed.

| Subchart | Key | Enabled by default | Description | Chart |
|----------|-----|--------------------|-------------|-------|
| [lfx-v2-auth-service](https://github.com/linuxfoundation/lfx-v2-auth-service) | `lfx-v2-auth-service` | `true` | NATS-based authentication and user management service that abstracts identity providers (Auth0 and Authelia) from the rest of the platform. | [lfx-v2-auth-service Helm Chart](https://github.com/linuxfoundation/lfx-v2-auth-service/tree/main/charts/lfx-v2-auth-service) |
| [lfx-v2-fga-sync](https://github.com/linuxfoundation/lfx-v2-fga-sync) | `lfx-v2-fga-sync` | `true` | Synchronizes authorization data between NATS and OpenFGA, and serves as a caching proxy for bulk access-check requests. | [lfx-v2-fga-sync Helm Chart](https://github.com/linuxfoundation/lfx-v2-fga-sync/tree/main/charts/lfx-v2-fga-sync) |
| [lfx-v2-access-check](https://github.com/linuxfoundation/lfx-v2-access-check) | `lfx-v2-access-check` | `true` | HTTP service that allows API consumers to perform bulk permission checks across LFX resources. | [lfx-v2-access-check Helm Chart](https://github.com/linuxfoundation/lfx-v2-access-check/tree/main/charts/lfx-v2-access-check) |
| [lfx-v2-indexer-service](https://github.com/linuxfoundation/lfx-v2-indexer-service) | `lfx-v2-indexer-service` | `true` | Processes resource change events from NATS and keeps OpenSearch in sync, propagating data updates across the platform. | [lfx-v2-indexer-service Helm Chart](https://github.com/linuxfoundation/lfx-v2-indexer-service/tree/main/charts/lfx-v2-indexer-service) |
| [lfx-v2-query-service](https://github.com/linuxfoundation/lfx-v2-query-service) | `lfx-v2-query-service` | `true` | HTTP service for performing access-controlled queries against LFX resources, including typeahead and full-text search. | [lfx-v2-query-service Helm Chart](https://github.com/linuxfoundation/lfx-v2-query-service/tree/main/charts/lfx-v2-query-service) |
| [lfx-v2-email-service](https://github.com/linuxfoundation/lfx-v2-email-service) | `lfx-v2-email-service` | `true` | Thin transactional email relay that receives pre-rendered email payloads over NATS and delivers them via Amazon SES. | [lfx-v2-email-service Helm Chart](https://github.com/linuxfoundation/lfx-v2-email-service/tree/main/charts/lfx-v2-email-service) |
| [lfx-v2-invite-service](https://github.com/linuxfoundation/lfx-v2-invite-service) | `lfx-v2-invite-service` | `true` | Handles invite issuance and tracking — receives invite requests from resource services over NATS, renders the email, and persists records in NATS KV. | [lfx-v2-invite-service Helm Chart](https://github.com/linuxfoundation/lfx-v2-invite-service/tree/main/charts/lfx-v2-invite-service) |
| [lfx-v2-forwards-service](https://github.com/linuxfoundation/lfx-v2-forwards-service) | `lfx-v2-forwards-service` | `true` | Stateless NATS service that manages email alias forwarding routes via forwardemail.net; alias ownership remains in auth-service. | [lfx-v2-forwards-service Helm Chart](https://github.com/linuxfoundation/lfx-v2-forwards-service/tree/main/charts/lfx-v2-forwards-service) |
| [lfx-v1-sync-helper](https://github.com/linuxfoundation/lfx-v1-sync-helper) | `lfx-v1-sync-helper` | `true` | Monitors NATS KV stores for replicated v1 data and synchronizes it into the v2 platform APIs, handling data transformation and conflict resolution. | [lfx-v1-sync-helper Helm Chart](https://github.com/linuxfoundation/lfx-v1-sync-helper/tree/main/charts/lfx-v1-sync-helper) |
| [lfx-v2-persona-service](https://github.com/linuxfoundation/lfx-v2-persona-service) | `lfx-v2-persona-service` | `true` | Provides a fast, personalized summary of a user's involvement across Linux Foundation projects for UI/UX feature enablement. | [lfx-v2-persona-service Helm Chart](https://github.com/linuxfoundation/lfx-v2-persona-service/tree/main/charts/lfx-v2-persona-service) |

#### LFX resource service subcharts

Resource services are each responsible for managing a specific set of domain
data (e.g. meetings, committees). They rely on platform services to handle
cross-cutting concerns such as permission checks, search indexing, and email
notifications.

| Subchart | Key | Enabled by default | Description | Chart |
|----------|-----|--------------------|-------------|-------|
| [lfx-v2-project-service](https://github.com/linuxfoundation/lfx-v2-project-service) | `lfx-v2-project-service` | `true` | Manages LF project metadata, settings, and project-level configuration. | [lfx-v2-project-service Helm Chart](https://github.com/linuxfoundation/lfx-v2-project-service/tree/main/charts/lfx-v2-project-service) |
| [lfx-v2-committee-service](https://github.com/linuxfoundation/lfx-v2-committee-service) | `lfx-v2-committee-service` | `true` | Manages committees, members, invites, applications, links, and documents. | [lfx-v2-committee-service Helm Chart](https://github.com/linuxfoundation/lfx-v2-committee-service/tree/main/charts/lfx-v2-committee-service) |
| [lfx-v2-voting-service](https://github.com/linuxfoundation/lfx-v2-voting-service) | `lfx-v2-voting-service` | `true` | Wraps the ITX voting platform for ballots, elections, and vote management. | [lfx-v2-voting-service Helm Chart](https://github.com/linuxfoundation/lfx-v2-voting-service/tree/main/charts/lfx-v2-voting-service) |
| [lfx-v2-survey-service](https://github.com/linuxfoundation/lfx-v2-survey-service) | `lfx-v2-survey-service` | `true` | Wraps the ITX survey platform for scheduling and managing committee surveys. | [lfx-v2-survey-service Helm Chart](https://github.com/linuxfoundation/lfx-v2-survey-service/tree/main/charts/lfx-v2-survey-service) |
| [lfx-v2-meeting-service](https://github.com/linuxfoundation/lfx-v2-meeting-service) | `lfx-v2-meeting-service` | `true` | Manages meetings, agendas, recordings, and Zoom integration. | [lfx-v2-meeting-service Helm Chart](https://github.com/linuxfoundation/lfx-v2-meeting-service/tree/main/charts/lfx-v2-meeting-service) |
| [lfx-v2-mailing-list-service](https://github.com/linuxfoundation/lfx-v2-mailing-list-service) | `lfx-v2-mailing-list-service` | `true` | Wraps Groups.io for project mailing list provisioning and management. | [lfx-v2-mailing-list-service Helm Chart](https://github.com/linuxfoundation/lfx-v2-mailing-list-service/tree/main/charts/lfx-v2-mailing-list-service) |
| [lfx-v2-newsletter-service](https://github.com/linuxfoundation/lfx-v2-newsletter-service) | `lfx-v2-newsletter-service` | `true` | Owns newsletter persistence and send orchestration for project newsletters. | [lfx-v2-newsletter-service Helm Chart](https://github.com/linuxfoundation/lfx-v2-newsletter-service/tree/main/charts/lfx-v2-newsletter-service) |
| [lfx-v2-member-service](https://github.com/linuxfoundation/lfx-v2-member-service) | `lfx-v2-member-service` | `true` | Manages B2B organization memberships, tiers, and Salesforce-backed membership data. | [lfx-v2-member-service Helm Chart](https://github.com/linuxfoundation/lfx-v2-member-service/tree/main/charts/lfx-v2-member-service) |

#### Developing a service locally

When working on a specific service, you can disable its subchart here and
deploy it directly from the service repository instead. This lets you iterate
on local code changes without affecting the rest of the platform.

For example, to develop `lfx-v2-query-service` locally:

Disable it in your `values.local.yaml`:

```yaml
lfx-v2-query-service:
  enabled: false
```

Follow the local development instructions in the service repository to
build and deploy it against the running platform.

### Adding a new subchart

When adding an LFX service as a dependency of this umbrella chart:

1. Add a dependency entry to [`Chart.yaml`](Chart.yaml) with the OCI
   repository URL, a semver constraint (e.g. `~0.1.0`), and a
   `condition: <service>.enabled`.
2. Add a default values block in [`values.yaml`](values.yaml). At minimum,
   include `enabled: true`, `replicaCount: 1`, and `lfx.domain` for HTTP
   services. Set `externalSecretsOperator.enabled: false` when the service
   chart supports ESO — local development uses manually created Kubernetes
   secrets instead.
3. Regenerate the lock file:

   ```bash
   helm dependency build charts/lfx-platform
   ```

4. Add a row to the appropriate subchart table in this README.
5. If the service requires manual Kubernetes secrets for local development,
   document them in [Secrets setup](#secrets-setup).
6. Optionally add an entry to [`values.local.example.yaml`](values.local.example.yaml).
7. Do not manually bump the `version` field in [`Chart.yaml`](Chart.yaml) — CI
   replaces it during the release build (see the comment at the top of that
   file). Publishing is triggered by creating a GitHub release tag per the
   root [README release process](../../README.md#releases).
8. For staging and production, also follow the
   [Adding a New Service](https://github.com/linuxfoundation/lfx-v2-argocd/blob/main/README.md#adding-a-new-service)
   guide in `lfx-v2-argocd`. When a service is deployed as its own ArgoCD
   application, disable its subchart in `lfx-v2-argocd/values/global/lfx-platform.yaml`
   to avoid deploying it twice.

## Secrets setup

Some subcharts require Kubernetes secrets to exist in the namespace before
installing the chart. These secrets are only needed if the corresponding
subchart is enabled.

To check whether a subchart is enabled, look for its `enabled` field in
`charts/lfx-platform/values.yaml`:

```bash
grep -A1 "lfx-v2-voting-service:" charts/lfx-platform/values.yaml
# enabled: false  ← skip secret creation if false
```

Secret values are stored in the **LFX V2** vault in 1Password under the note
**LFX Platform Chart Values Secrets - Local Development**.

### lfx-v2-voting-service

Requires an Auth0 client ID and RSA private key.

```bash
kubectl create secret generic lfx-v2-voting-service -n lfx \
  --from-literal=ITX_CLIENT_ID="<from-1password>" \
  --from-file=ITX_CLIENT_PRIVATE_KEY=/path/to/private.key
```

### lfx-v2-survey-service

Requires an Auth0 client ID and RSA private key.

```bash
kubectl create secret generic lfx-v2-survey-service -n lfx \
  --from-literal=ITX_CLIENT_ID="<from-1password>" \
  --from-file=ITX_CLIENT_PRIVATE_KEY=/path/to/private.key
```

### lfx-v2-meeting-service

Requires an Auth0 client ID and RSA private key.

```bash
kubectl create secret generic meeting-secrets -n lfx \
  --from-literal=auth0_client_id="<from-1password>" \
  --from-file=auth0_client_private_key=/path/to/private.key
```

### lfx-v2-mailing-list-service

Requires Groups.io credentials and a webhook secret.

```bash
kubectl create secret generic lfx-v2-mailing-list-service -n lfx \
  --from-literal=GROUPSIO_EMAIL="<from-1password>" \
  --from-literal=GROUPSIO_PASSWORD="<from-1password>" \
  --from-literal=GROUPSIO_WEBHOOK_SECRET="<from-1password>"
```

## Using external PostgreSQL with OpenFGA

To use an external PostgreSQL database with OpenFGA:

1. Create a secret with the PostgreSQL connection string:

```bash
kubectl create secret generic openfga-postgresql-client \
  --from-literal="uri=postgres://username:password@postgres-host:5432/dbname?sslmode=disable" \
  -n lfx
```

1. Configure OpenFGA in your values file:

```yaml
openfga:
  postgres:
    enabled: false
  datastore:
    existingSecret: openfga-postgresql-client
```

## Jaeger

Jaeger provides distributed tracing capabilities for the LFX platform.
It should be installed in a separate `observability` namespace.

### Jaeger Prerequisites

Add the Jaeger Helm repository:

```bash
helm repo add jaegertracing https://jaegertracing.github.io/helm-charts
helm repo update
```

### Installing Jaeger

Install Jaeger using the all-in-one chart (suitable for development/testing):

```bash
helm install jaeger jaegertracing/jaeger \
  -n observability \
  --create-namespace \
  --set allInOne.enabled=true \
  --set agent.enabled=false \
  --set collector.enabled=false \
  --set query.enabled=false \
  --set storage.type=memory \
  --set provisionDataStore.cassandra=false
```

### Set Helm Values

Either update `charts/lfx-platform/values.yaml` directly or create a new
`tracing-values.yaml` file with the following values to enable traces to
be sent to Jaeger.

#### Traefik Values

```yaml
traefik:
  tracing:
    otlp:
      enabled: true
```

#### OpenFGA Values

```yaml
openfga:
  telemetry:
    trace:
      enabled: true
```

#### Heimdall Values

```yaml
heimdall:
  env:
    HEIMDALLCFG_TRACING_ENABLED: "true"
```

### Upgrade Helm Deployment

Then upgrade the helm deployment.

```bash
helm upgrade lfx-platform charts/lfx-platform
```

If using a values file, pass it to the command:

```bash
helm upgrade -f tracing-values.yaml lfx-platform charts/lfx-platform
```

### Accessing Jaeger UI

To access the Jaeger UI locally:

```bash
kubectl port-forward -n observability svc/jaeger-query 16686:16686
```

Then open `http://localhost:16686` in your browser.
