# LFX Platform helm chart

This Helm chart deploys platform services and key resource APIs for LFX v2 development.

## Prerequisites

- Kubernetes 1.19+
- Helm 3.2.0+
- PV provisioner support in the underlying infrastructure (if persistence is enabled)

## Add chart repositories

```bash
helm repo add traefik https://traefik.github.io/charts
helm repo add dadrus https://dadrus.github.io/heimdall/charts
helm repo add nats https://nats-io.github.io/k8s/helm/charts/
helm repo add openfga https://openfga.github.io/helm-charts
helm repo add opensearch https://opensearch-project.github.io/helm-charts
helm repo add jouve https://jouve.github.io/charts/
helm repo update
```

## Installing the chart

To install the chart with the release name `lfx-platform`:

```bash
kubectl create namespace lfx
helm install lfx-platform . -n lfx -f values.yaml
```

## Uninstalling the chart

To uninstall/delete the `lfx-platform` deployment:

```bash
helm uninstall lfx-platform -n lfx
```

## Configuration

The following table lists the configurable parameters of the LFX Platform chart and their default values.

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
