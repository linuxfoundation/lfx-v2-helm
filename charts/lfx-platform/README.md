# LFX platform umbrella Helm chart

This Helm chart deploys infrastructure components, platform services, and key
resource APIs for the LFX platform.

## Prerequisites

- Kubernetes 1.19+
- Helm 3.2.0+
- PV provisioner support in the underlying infrastructure (if persistence is
  enabled)

## Installing the chart

### Installing via the OCI registry

```bash
# Create namespace (recommended).
kubectl create namespace lfx

# Install the chart.
helm install -n lfx lfx-platform \
  oci://ghcr.io/linuxfoundation/lfx-v2-helm/chart/lfx-platform \
  --version 0.1.1
```

### Installing from source

Clone the repository before running the following commands from the root of the
working directory.

```bash
# Create namespace (recommended).
kubectl create namespace lfx

# Pull down chart dependencies.
helm dependency update charts/lfx-platform

# Install the chart.
helm install -n lfx lfx-platform \
    ./charts/lfx-platform
```

## Uninstalling the chart

To uninstall/delete the `lfx-platform` deployment:

```bash
helm uninstall lfx-platform -n lfx
# Optional: delete the namespace to delete any persistent resources.
kubectl delete namespace lfx
```

## Configuration

The following table lists the configurable parameters of the LFX Platform chart
and their default values. You can override these values in your own
`values.yaml` file or by using the `--set` flag when installing the chart.

### Global parameters

| Parameter              | Description                     | Default           |
|------------------------|---------------------------------|-------------------|
| `lfx.domain`           | Domain for services             | `k8s.orb.local`   |
| `lfx.image.registry`   | Global Docker image registry    | `linuxfoundation` |
| `lfx.image.pullPolicy` | Global Docker image pull policy | `IfNotPresent`    |

### Subchart configuration

#### Traefik

| Parameter                                | Description              | Default |
|------------------------------------------|--------------------------|---------|
| `traefik.enabled`                        | Enable Traefik           | `true`  |
| `traefik.ingressRoute.dashboard.enabled` | Enable Traefik dashboard | `true`  |

For more Traefik configuration options, see the [Traefik Helm Chart documentation](https://github.com/traefik/traefik-helm-chart).

#### OpenFGA

| Parameter                          | Description                                      | Default |
|------------------------------------|--------------------------------------------------|---------|
| `openfga.enabled`                  | Enable OpenFGA                                   | `true`  |
| `openfga.postgres.enabled`         | Enable built-in PostgreSQL                       | `true`  |
| `openfga.datastore.existingSecret` | Secret for external PostgreSQL connection string | `nil`   |

For more OpenFGA configuration options, see the [OpenFGA Helm Chart documentation](https://github.com/openfga/helm-charts).

For information on managing OpenFGA see the [OpenFGA Documentation](../../docs/openfga.md).

#### Heimdall

| Parameter                              | Description                             | Default            |
|----------------------------------------|-----------------------------------------|--------------------|
| `heimdall.enabled`                     | Enable Heimdall                         | `true`             |
| `heimdall.autheliaIntegration.enabled` | Enable Authelia integration             | `true`             |
| `heimdall.secretsRef`                  | Heimdall secrets reference              | `heimdall-secrets` |
| `heimdall.certsSecretRef`              | Heimdall certificates secrets reference | `heimdall-certs`   |

For more Heimdall configuration options, see the [Heimdall Helm Chart documentation](https://github.com/dadrus/heimdall/tree/main/charts/heimdall).

#### NATS

| Parameter                | Description             | Default |
|--------------------------|-------------------------|---------|
| `nats.enabled`           | Enable NATS             | `true`  |
| `nats.cluster.enabled`   | Enable NATS clustering  | `true`  |
| `nats.cluster.replicas`  | Number of NATS replicas | `3`     |
| `nats.jetstream.enabled` | Enable JetStream        | `true`  |

For more NATS configuration options, see the [NATS Helm Chart documentation](https://github.com/nats-io/k8s/tree/main/helm/charts/nats).

#### Mailpit

| Parameter         | Description    | Default |
|-------------------|----------------|---------|
| `mailpit.enabled` | Enable Mailpit | `true`  |

For more mailpit configuration options, see the [Mailpit documentation](https://github.com/jouve/charts/tree/main/charts/mailpit).

#### Authelia

| Parameter          | Description     | Default |
|--------------------|-----------------|---------|
| `authelia.enabled` | Enable Authelia | `true`  |

For more authelia configuration options, see the [Authelia documentation](https://github.com/authelia/chartrepo/tree/master/charts/authelia).

#### NACK

| Parameter      | Description | Default |
|----------------|-------------|---------|
| `nack.enabled` | Enable Nack | `true`  |

For more NACK configuration options, see the [NACK documentation](https://github.com/nats-io/k8s/tree/main/helm/charts/nack).

## Using external PostgreSQL with OpenFGA

To use an external PostgreSQL database with OpenFGA:

1. Create a secret with the PostgreSQL connection string:

```bash
kubectl create secret generic openfga-postgresql-client \
  --from-literal="uri=postgres://username:password@postgres-host:5432/dbname?sslmode=disable" \
  -n lfx
```

2. Configure OpenFGA in your values file:

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
