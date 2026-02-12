# LFX Service Helm Chart

A flexible, reusable Helm chart for deploying LFX Platform V2 microservices. This chart follows Helm best practices and provides a consistent deployment pattern across all LFX services.

## Features

- **Flexible Environment Variables**: Support for both direct values and secret/configmap references
- **Gateway API Support**: HTTPRoute configuration for modern Kubernetes ingress
- **Heimdall Integration**: Built-in authentication middleware and rulesets
- **NATS KV Buckets**: Automated creation of NATS KeyValue stores
- **External Secrets Integration**: AWS Secrets Manager support with automatic gating
- **Consistent Labels & Annotations**: Merged chart-wide and resource-specific labels/annotations
- **Production Ready**: Includes HPA, PDB, resource limits, and health checks
- **Extensible**: Easy to add new features without breaking existing deployments

## Quick Start

```bash
# Install a service using this chart
helm install my-service ./lfx-service \
  --set image.repository=ghcr.io/linuxfoundation/my-service \
  --set image.tag=v1.0.0 \
  --values my-service-values.yaml
```

## Configuration

### Global Settings

These settings affect the entire chart and multiple resources:

```yaml
# Global configuration
global:
  domain: k8s.orb.local          # Domain for routing
  namespace: ""                 # Target namespace (optional) defaults to release namespace
  awsRegion: ""                  # AWS region (required for External Secrets)

# Chart metadata
nameOverride: ""                 # Override chart name
fullnameOverride: ""            # Override full resource names (optional)

# Chart-wide labels and annotations applied to all resources
commonLabels:
  team: platform
  environment: production

commonAnnotations:
  monitoring.coreos.com/enabled: "true"

# Required: Container image
image:
  repository: "ghcr.io/linuxfoundation/my-service"  # Required
  tag: ""                        # Defaults to Chart.AppVersion
  pullPolicy: IfNotPresent
```

### Deployment

Controls the main application deployment:

```yaml
deployment:
  # Replica configuration
  replicaCount: 1
  
  # Container configuration
  port: 8080
  
  # Environment variables (supports valueFrom)
  environment:
    LOG_LEVEL:
      value: "info"
    DATABASE_PASSWORD:
      valueFrom:
        secretKeyRef:
          name: db-secret
          key: password
  
  # Security context
  securityContext:
    allowPrivilegeEscalation: false
  
  # Resource limits
  resources:
    requests:
      memory: "128Mi"
      cpu: "100m"
    limits:
      memory: "512Mi"
      cpu: "500m"
  
  # Node scheduling
  nodeSelector: {}
  tolerations: []
  affinity: {}
  
  # Health check configuration
  healthChecks:
    enabled: true
    livenessProbe:
      httpGet:
        path: /livez
        port: web
      failureThreshold: 3
      periodSeconds: 15
    readinessProbe:
      httpGet:
        path: /readyz
        port: web
      failureThreshold: 1
      periodSeconds: 10
    startupProbe:
      httpGet:
        path: /readyz
        port: web
      failureThreshold: 30
      periodSeconds: 1
  
  # Deployment-specific labels/annotations
  labels: {}
  annotations: {}
```

### Service

Creates a Kubernetes Service for the application:

```yaml
service:
  enabled: true
  type: ClusterIP
  port: 8080
  labels: {}
  annotations: {}
```

### ServiceAccount

Manages the service account and RBAC:

```yaml
serviceAccount:
  create: true
  name: ""                       # Defaults to release name
  automountServiceAccountToken: true
  labels: {}
  annotations: {
    "eks.amazonaws.com/role-arn": arn:aws:iam::1234567890:role/SERVICE-NAME
  }
```

### HTTPRoute (Gateway API)

Configures ingress routing using Gateway API:

```yaml
httpRoute:
  enabled: false
  gateway:
    name: lfx-platform-gateway
    namespace: lfx
  
  # Custom hostnames (defaults to lfx-api.{global.domain})
  hostnames: []
  
  # Path matching rules
  matches:
    - path:
        type: PathPrefix
        value: /api/v1/service/
    - path:
        type: Exact
        value: /health
  
  # Middleware filters
  filters:
    - type: ExtensionRef
      extensionRef:
        group: traefik.io
        kind: Middleware
        name: heimdall-forward-body
  
  labels: {}
  annotations: {}
```

### Heimdall Middleware

Creates Traefik middleware for Heimdall authentication:

```yaml
heimdall:
  enabled: false
  url: http://lfx-platform-heimdall.lfx.svc.cluster.local:4456
  createMiddleware: false        # Whether to create middleware resources
  forwardBody: true             # Enable body forwarding
  labels: {}
  annotations: {}
```

### RuleSet

Defines Heimdall authentication and authorization rules:

```yaml
ruleSet:
  enabled: false
  audience: my-service          # JWT audience
  useOidcContextualizer: true   # Add OIDC context
  openfgaEnabled: true          # Enable OpenFGA authorization
  
  # Authentication rules
  rules:
    - id: "rule:my-service:create"
      match:
        methods: ["POST"]
        routes: ["/api/v1/resource"]
      authorization:
        relation: writer
        object: "project:{{.Request.Body.project_uid}}"
  
  labels: {}
  annotations: {}
```

### NATS KV Buckets

Creates NATS KeyValue storage buckets:

```yaml
nats:
  kvBuckets:
    - name: service-data
      creation: true             # Create the bucket
      keep: true                 # Add helm.sh/resource-policy: keep
      history: 20                # Number of historical values
      storage: file              # Storage type
      maxValueSize: 10485760     # 10MB max value size
      maxBytes: 1073741824       # 1GB total bucket size
      compression: true          # Enable compression
  
  labels: {}
  annotations: {}
```

### Horizontal Pod Autoscaler

Configures automatic scaling based on metrics:

```yaml
autoscaling:
  enabled: false
  minReplicas: 1
  maxReplicas: 10
  targetCPUUtilizationPercentage: 80
  targetMemoryUtilizationPercentage: 80  # Optional
  labels: {}
  annotations: {}
```

### Pod Disruption Budget

Controls disruption during updates and node maintenance:

```yaml
podDisruptionBudget:
  enabled: false
  minAvailable: 1               # Or use maxUnavailable
  # maxUnavailable: 1
  labels: {}
  annotations: {}
```

### External Secrets Operator

Integrates with AWS Secrets Manager (requires `global.awsRegion`):

```yaml
externalSecretsOperator:
  enabled: false
  
  # SecretStore configuration
  secretStore:
    name: ""                     # Defaults to "{release-name}-secret-store"
    labels: {}
    annotations: {}
  
  # ExternalSecret configuration
  externalSecret:
    name: ""                     # Defaults to "{release-name}-external-secret"
    refreshInterval: "10m"
    labels: {}
    annotations: {}
    
    # Target secret configuration
    target:
      name: ""                   # Defaults to "{release-name}-secrets"
      creationPolicy: "Owner"
      deletionPolicy: "Retain"
      template: {}
    
    # Secret data configuration
    # IMPORTANT: Use EITHER data OR dataFrom, never both
    # If both are empty, defaults to tag-based discovery
    
    # Individual secret mappings
    data:
      - secretKey: database-password
        remoteRef:
          key: /app/database
          property: password
      - secretKey: api-key
        remoteRef:
          key: /app/api-credentials
          property: key
    
    # Bulk secret import (alternative to data)
    dataFrom: []
      # - extract:
      #     key: /app/all-secrets
      # - find:
      #     name:
      #       regexp: ".*"
```


## Values Reference

| Parameter | Description | Default |
|-----------|-------------|---------|
| `image.repository` | Container image repository | `""` (required) |
| `image.tag` | Container image tag | Chart.appVersion |
| `image.pullPolicy` | Image pull policy | `IfNotPresent` |
| `app.replicaCount` | Number of replicas | `1` |
| `app.port` | Application port | `8080` |
| `app.environment` | Environment variables map | `{}` |
| `service.enabled` | Create service | `true` |
| `service.port` | Service port | `8080` |
| `httpRoute.enabled` | Create HTTPRoute | `false` |
| `heimdall.enabled` | Enable Heimdall auth | `false` |
| `ruleSet.enabled` | Create RuleSet | `false` |
| `nats.kvBuckets` | NATS KV bucket configurations | `[]` |
| `externalSecretsOperator.enabled` | Enable External Secrets Operator | `false` |
| `externalSecretsOperator.externalSecret.data` | Individual secret mappings | `[]` |
| `externalSecretsOperator.externalSecret.dataFrom` | Bulk secret import | `[]` |
| `externalSecretsOperator.externalSecret.refreshInterval` | Secret refresh interval | `"1h"` |
| `serviceAccount.awsRoleArn` | AWS IAM role for External Secrets | `""` |
| `global.awsRegion` | AWS region for External Secrets | `""` (blank for local) |
| `commonLabels` | Labels applied to all resources | `{}` |
| `commonAnnotations` | Annotations applied to all resources | `{}` |
| `*.labels` | Resource-specific labels (merged with common) | `{}` |
| `*.annotations` | Resource-specific annotations (merged with common) | `{}` |

See [values.yaml](values.yaml) for complete configuration options.

## Examples

### Basic Service

```yaml
image:
  repository: ghcr.io/linuxfoundation/my-service
  tag: v1.0.0

app:
  environment:
    LOG_LEVEL:
      value: info
```

### Local Testing

```bash
# Render templates locally
helm template my-service ./lfx-service --values examples/meeting-service-values.yaml

# Validate chart
helm lint ./lfx-service

# Test installation
helm install --dry-run my-service ./lfx-service --values examples/meeting-service-values.yaml
```
