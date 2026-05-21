# LFX platform umbrella Helm chart

This Helm chart deploys infrastructure components, platform services, and key
resource APIs for the LFX platform.

## Prerequisites

- Kubernetes 1.19+
- Helm 3.2.0+
- PV provisioner support in the underlying infrastructure (if persistence is
  enabled)

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

Each subchart can be enabled or disabled via its `enabled` key. Refer to the
linked documentation for the full set of configuration options.

#### Infrastructure subcharts

| Subchart       | Key             | Enabled by default | Documentation |
|----------------|-----------------|-------------------|---------------|
| Traefik        | `traefik`       | `true`            | [Traefik Helm Chart](https://github.com/traefik/traefik-helm-chart) |
| OpenFGA        | `openfga`       | `true`            | [OpenFGA Helm Chart](https://github.com/openfga/helm-charts) · [Local docs](../../docs/openfga.md) |
| Heimdall       | `heimdall`      | `true`            | [Heimdall Helm Chart](https://github.com/dadrus/heimdall/tree/main/charts/heimdall) |
| NATS           | `nats`          | `true`            | [NATS Helm Chart](https://github.com/nats-io/k8s/tree/main/helm/charts/nats) |
| NACK           | `nack`          | `true`            | [NACK documentation](https://github.com/nats-io/k8s/tree/main/helm/charts/nack) |
| OpenSearch     | `opensearch`    | `true`            | [OpenSearch Helm Chart](https://github.com/opensearch-project/helm-charts) |
| Authelia       | `authelia`      | `true`            | [Authelia documentation](https://github.com/authelia/chartrepo/tree/master/charts/authelia) |
| Mailpit        | `mailpit`       | `true`            | [Mailpit documentation](https://github.com/jouve/charts/tree/main/charts/mailpit) |
| External Secrets Operator | `external-secrets` | `true`       | [External Secrets Helm Chart](https://external-secrets.io/latest/introduction/getting-started/) |
| cert-manager   | `cert-manager`  | `false`           | [cert-manager Helm Chart](https://cert-manager.io/docs/installation/helm/) |
| fga-operator   | `fga-operator`  | `true`            | — |

#### LFX service subcharts

| Subchart                    | Key                           | Enabled by default | Chart |
|-----------------------------|-------------------------------|-------------------|-------|
| lfx-v2-auth-service         | `lfx-v2-auth-service`         | `true`            | [lfx-v2-auth-service Helm Chart](https://github.com/linuxfoundation/lfx-v2-auth-service/tree/main/charts/lfx-v2-auth-service) |
| lfx-v2-fga-sync             | `lfx-v2-fga-sync`             | `true`            | [lfx-v2-fga-sync Helm Chart](https://github.com/linuxfoundation/lfx-v2-fga-sync/tree/main/charts/lfx-v2-fga-sync) |
| lfx-v2-access-check         | `lfx-v2-access-check`         | `true`            | [lfx-v2-access-check Helm Chart](https://github.com/linuxfoundation/lfx-v2-access-check/tree/main/charts/lfx-v2-access-check) |
| lfx-v2-indexer-service      | `lfx-v2-indexer-service`      | `true`            | [lfx-v2-indexer-service Helm Chart](https://github.com/linuxfoundation/lfx-v2-indexer-service/tree/main/charts/lfx-v2-indexer-service) |
| lfx-v2-query-service        | `lfx-v2-query-service`        | `true`            | [lfx-v2-query-service Helm Chart](https://github.com/linuxfoundation/lfx-v2-query-service/tree/main/charts/lfx-v2-query-service) |
| lfx-v2-project-service      | `lfx-v2-project-service`      | `true`            | [lfx-v2-project-service Helm Chart](https://github.com/linuxfoundation/lfx-v2-project-service/tree/main/charts/lfx-v2-project-service) |
| lfx-v2-committee-service    | `lfx-v2-committee-service`    | `true`            | [lfx-v2-committee-service Helm Chart](https://github.com/linuxfoundation/lfx-v2-committee-service/tree/main/charts/lfx-v2-committee-service) |
| lfx-v2-voting-service       | `lfx-v2-voting-service`       | `true`            | [lfx-v2-voting-service Helm Chart](https://github.com/linuxfoundation/lfx-v2-voting-service/tree/main/charts/lfx-v2-voting-service) |
| lfx-v2-survey-service       | `lfx-v2-survey-service`       | `true`            | [lfx-v2-survey-service Helm Chart](https://github.com/linuxfoundation/lfx-v2-survey-service/tree/main/charts/lfx-v2-survey-service) |
| lfx-v2-meeting-service      | `lfx-v2-meeting-service`      | `true`            | [lfx-v2-meeting-service Helm Chart](https://github.com/linuxfoundation/lfx-v2-meeting-service/tree/main/charts/lfx-v2-meeting-service) |
| lfx-v2-mailing-list-service | `lfx-v2-mailing-list-service` | `true`            | [lfx-v2-mailing-list-service Helm Chart](https://github.com/linuxfoundation/lfx-v2-mailing-list-service/tree/main/charts/lfx-v2-mailing-list-service) |
| lfx-v2-email-service        | `lfx-v2-email-service`        | `true`            | [lfx-v2-email-service Helm Chart](https://github.com/linuxfoundation/lfx-v2-email-service/tree/main/charts/lfx-v2-email-service) |
| lfx-v2-invite-service       | `lfx-v2-invite-service`       | `true`            | [lfx-v2-invite-service Helm Chart](https://github.com/linuxfoundation/lfx-v2-invite-service/tree/main/charts/lfx-v2-invite-service) |
| lfx-v2-email-service        | `lfx-v2-email-service`        | `true`            | [lfx-v2-email-service Helm Chart](https://github.com/linuxfoundation/lfx-v2-email-service/tree/main/charts/lfx-v2-email-service) |
| lfx-v2-invite-service       | `lfx-v2-invite-service`       | `true`            | [lfx-v2-invite-service Helm Chart](https://github.com/linuxfoundation/lfx-v2-invite-service/tree/main/charts/lfx-v2-invite-service) |

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
