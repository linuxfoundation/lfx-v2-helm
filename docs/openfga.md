# OpenFGA Documentation

This document provides comprehensive guidance on managing OpenFGA stores and authorization models in the LFX Platform, including how to create, update, and query stores and models using both the fga-operator and direct CLI commands.

## Overview

OpenFGA (Open Fine-Grained Authorization) is a modern authorization system that provides flexible, high-performance authorization for applications. The LFX Platform uses OpenFGA for managing authorization models and stores through the [fga-operator](https://github.com/3schwartz/fga-operator).

## Architecture

The fga-operator automates the synchronization between your Kubernetes deployments and OpenFGA authorization models. It provides:

- **AuthorizationModelRequest**: Defines authorization models and creates stores
- **Store**: Kubernetes resource representing an OpenFGA store
- **AuthorizationModel**: Kubernetes resource representing an authorization model
- **Automatic Deployment Updates**: Updates deployments with latest model IDs

## Quick Start

### 1. Verify the Model Deployed

The LFX Platform includes a pre-configured authorization model that's automatically deployed when you install the chart. The model can be found in `charts/lfx-platform/templates/openfga/model.yaml`. Check that it deployed successfully:

```bash
# Check AuthorizationModelRequest status
kubectl get AuthorizationModelRequest -n lfx

# Check Store resource
kubectl get Store -n lfx

# Check AuthorizationModel resource
kubectl get AuthorizationModel -n lfx
```

### 2. View the Authorization Model Details

Get detailed information about the deployed authorization model:

```bash
# Get the store name from values (default is 'lfx-core')
STORE_NAME=$(helm get values lfx-platform -n lfx -o json | jq -r '.["fga-operator"].store // "lfx-core"')

# View the authorization model details
kubectl get AuthorizationModel/$STORE_NAME -n lfx -o yaml
```

This will show you the model ID, version, and the complete authorization model definition.

## Managing Stores and Models

### Listing Stores

Use the fga-cli to list all stores:

```bash
kubectl run --rm -it fga-cli --namespace lfx --image=openfga/cli --env="FGA_API_URL=http://lfx-platform-openfga:8080" --restart=Never -- store list
```

### Listing Models

List all authorization models for a specific store:

```bash
# First, get the store ID
STORE_ID="$(kubectl get Store lfx-core -n lfx -o jsonpath='{.spec.id}')"

# Then list models
kubectl run --rm -it fga-cli --namespace lfx --image=openfga/cli --env="FGA_STORE_ID=$STORE_ID" --env="FGA_API_URL=http://lfx-platform-openfga:8080" --restart=Never -- model list
```

### Getting Model Details

Get detailed information about a specific model:

```bash
# Get model details (replace MODEL_ID with actual ID)
kubectl run --rm -it fga-cli --namespace lfx --image=openfga/cli --env="FGA_STORE_ID=$STORE_ID" --env="FGA_API_URL=http://lfx-platform-openfga:8080" --restart=Never -- model get --id MODEL_ID
```

## Updating Authorization Models

To update the authorization model, modify the version and model definition in `charts/lfx-platform/templates/openfga/model.yaml`:

1. **Increment the version** in the `instances` section:
   ```yaml
   instances:
     - version:
         major: 1
         minor: 1
         patch: 3  # Bump this version number
   authorizationModel: |
     model
       schema 1.1

     type user

     type team
       relations
         define member: [user]

     type project
       relations
         define parent: [project]
         define owner: [team#member] or owner from parent
         define writer: owner or writer from parent
         define auditor: [user, team#member] or writer or auditor from parent
         define viewer: [user:*] or auditor or auditor from parent
         # Add new relations here as needed
   ```

2. **Redeploy the chart** to apply the changes:
   ```bash
   helm upgrade lfx-platform ./charts/lfx-platform -n lfx
   ```

The fga-operator will automatically detect the version change and create a new authorization model in OpenFGA while keeping the existing model for backward compatibility.

## Deployment Integration

### Automatic Environment Variable Updates

The fga-operator automatically updates deployments with the `openfga-store` label. When you create or update an authorization model, the operator will:

1. Update the `OPENFGA_AUTH_MODEL_ID` environment variable
2. Update the `OPENFGA_STORE_ID` environment variable
3. Add annotations with timestamps and version information

### Example Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: whoami
  namespace: lfx
  labels:
    openfga-store: lfx-core
    # Set a version to use a specific model
    # openfga-auth-model-version: 1.2.3
spec:
  replicas: 1
  selector:
    matchLabels:
      app: whoami
  template:
    metadata:
      labels:
        app: whoami
    spec:
      containers:
      - name: api
        image: traefik/whoami:latest
        env:
        - name: OPENFGA_API_URL
          value: "http://lfx-platform-openfga:8080"
        # OPENFGA_AUTH_MODEL_ID and OPENFGA_STORE_ID will be automatically set
```

### Checking Deployment Updates

Verify that your deployment updated with the latest model information:

```bash
# Check environment variables
kubectl get deployment whoami -n lfx -o jsonpath='{.spec.template.spec.containers[0].env}'

# Check annotations
kubectl get deployment whoami -n lfx -o jsonpath='{.metadata.annotations}'
```

## Querying Authorization Data

### Writing Tuples

Add authorization relationships:

```bash
# Add a user as owner of a project
kubectl run --rm -it fga-cli --namespace lfx --image=openfga/cli --env="FGA_STORE_ID=$STORE_ID" --env="FGA_API_URL=http://lfx-platform-openfga:8080" --restart=Never -- tuple write --tuple "user:john@example.com:owner:project:project1"
```

### Reading Tuples

Query existing relationships:

```bash
# List all tuples
kubectl run --rm -it fga-cli --namespace lfx --image=openfga/cli --env="FGA_STORE_ID=$STORE_ID" --env="FGA_API_URL=http://lfx-platform-openfga:8080" --restart=Never -- tuple read

# Query specific relationships
kubectl run --rm -it fga-cli --namespace lfx --image=openfga/cli --env="FGA_STORE_ID=$STORE_ID" --env="FGA_API_URL=http://lfx-platform-openfga:8080" --restart=Never -- tuple read --tuple "user:john@example.com:owner:project:project1"
```

### Checking Authorization

Test authorization decisions:

```bash
# Check if a user can read a project
kubectl run --rm -it fga-cli --namespace lfx --image=openfga/cli --env="FGA_STORE_ID=$STORE_ID" --env="FGA_API_URL=http://lfx-platform-openfga:8080" --restart=Never -- check --tuple "user:john@example.com:reader:project:project1"
```

## Advanced Topics

### Events and Monitoring

Monitor operator events:

```bash
# Check events
kubectl get events -n lfx --sort-by='.lastTimestamp'

# Check specific resource events
kubectl describe AuthorizationModelRequest lfx-core -n lfx
```

## References

- [OpenFGA Documentation](https://openfga.dev/)
- [fga-operator GitHub Repository](https://github.com/3schwartz/fga-operator)
- [OpenFGA CLI Documentation](https://openfga.dev/docs/getting-started/cli)
- [OpenFGA Helm Chart](https://github.com/openfga/helm-charts)
