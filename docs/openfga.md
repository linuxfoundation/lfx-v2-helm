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

The LFX Platform includes a pre-configured authorization model that's automatically deployed when you install the chart. The canonical model DSL lives in `charts/lfx-platform/files/model.fga`; the Helm template at `charts/lfx-platform/templates/openfga/model.yaml` injects it along with the versioning metadata. Check that it deployed successfully:

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

To update the authorization model:

1. **Edit the model DSL** in `charts/lfx-platform/files/model.fga` — this is the single source of truth.

2. **Increment the version** in `charts/lfx-platform/templates/openfga/model.yaml`:
   ```yaml
   instances:
     - version:
         major: X      # bump the appropriate component
         minor: Y
         patch: Z
       authorizationModel: |
{{ .Files.Get "files/model.fga" | indent 8 }}
   ```
   Note: the `{{ .Files.Get ... }}` line starts at column 0 in the template
   file — `indent 8` provides the required indentation for the YAML block scalar.

   CI will fail if `files/model.fga` changes without any corresponding change to `model.yaml`. The version bump itself is a social contract — CI verifies the files were edited together, not that the numbers were incremented.

3. **Regenerate `PERMISSIONS.md`** by running the render-permissions agent skill to keep the human-readable permissions reference in sync.

4. **Redeploy the chart** to apply the changes:
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
# Check if a user can write to a project (a tuple-dependent relation).
# Note: `project#viewer` is public in the model (`define viewer: [user:*] ...`),
# so a `viewer` check always returns allowed even with no tuples. Use a
# restrictive relation like `writer` or `auditor` for a meaningful check that
# actually validates the tuples you have written.
kubectl run --rm -it fga-cli --namespace lfx --image=openfga/cli --env="FGA_STORE_ID=$STORE_ID" --env="FGA_API_URL=http://lfx-platform-openfga:8080" --restart=Never -- check --tuple "user:john@example.com:writer:project:project1"
```

## Provisioning Manually-Managed Global Tuples

Some tuples are global/ROOT-scoped and have no owning service to write them
automatically — they're seeded once by hand and rely on `... from parent`
cascades in the model to apply everywhere. The Marketing Ops role added in
LFXV2-2231 is the first example: `marketing_ops` is granted on
`project:ROOT` and cascades to every project via
`marketing_ops from parent` (which `marketing_auditor` and
`campaign_manager` both resolve through).

There is currently no admin UI for this (tracked separately as LFXV2-1760)
and no service writes these tuples — not project-service (its
`root-project-setup` is create-once and accepts `user:` subjects only) and
not fga-sync (LFXV2-2233 was cancelled, LFXV2-2234 is not started) — manual
`tuple write` via the OpenFGA CLI, as shown above, is the only path today.
That makes two things easy to get wrong during an incident: nobody owns
re-checking that a global tuple still exists, and there's no record to
consult to rule out "was it ever written" as a cause.

`project:ROOT` in the prose below is shorthand for the tenant root project.
OpenFGA has no such object: the real object is `project:<rootProjectId>`, a
UUID that differs per environment (argocd `values/<env>/lfid-management.yaml`,
key `rootProjectId`). Never pass the literal `project:ROOT` to `tuple write`
or `tuple read` — it would create or look up a disconnected tuple that
nothing cascades from. The runbook commands below read the ID into
`ROOT_PROJECT_ID` first and use `project:$ROOT_PROJECT_ID`.

**Global auditor rule (spec 044 / ADR-0041).** The ROOT `auditor` relation
is load-bearing for a job, not only for the model cascade. Every
`team:<name>#member` subject holding a *direct* `auditor` tuple on
`project:ROOT` is, by definition, a global-auditor population: the model
cascades it to every project (`auditor from parent`), and the
`sync-global-groups` CronJob (argocd
`custom-resources/lfx-v2-fga-sync-global-groups`) reads those team subjects
every 10 minutes and grants each team blanket `auditor` on every `b2b_org`,
which the project cascade cannot reach (`b2b_org#parent` is another
`b2b_org`). `user:` subjects and ROOT `owner`/`writer` teams are ignored.
The reconciler is not the only writer of those per-org grants: member-service
publishes the same `team:<name>#member → auditor → b2b_org:<uid>` tuples on
every org write, driven by its own `LF_STAFF_TEAM_NAME` /
`LF_CONTRACTOR_TEAM_NAME` chart values (see member-service
`docs/lf-team-auditor-grants.md`). The two are meant to agree, but they are
configured independently. Consequences when you edit this table: adding a
team here extends Org Lens read access to every organization within ~10
minutes; removing a team stops the *reconciler's* new per-org grants only —
member-service keeps emitting for a team until its chart value is cleared —
and revokes nothing already written: the reconciler is write-only, and
fga-sync never deletes a tuple whose *subject* is a `team:<name>#member`
reference (the per-org grants). Team *membership* tuples
— `user:<lfid>` subjects on a `team:` object — are a different thing: the
`sync-global-groups` CronJob itself adds and removes them (`syncGroup`, a
direct OpenFGA `/write`, not the fga-sync service — the Application name
conflates the two), so LDAP offboarding still drops a member's `team:`
membership. Revoking the per-org grants is member-service's
`scripts/revoke-lf-teams-auditor-openfga.sh`. If no team
holds ROOT `auditor` in an environment, the reconcile step fails closed and
logs `org reconcile failed`; LDAP member sync is unaffected.

**Owner:** LF Staff Support (per the LFXV2-2231 epic's decision to defer
manual tuple management there until LFXV2-1760 ships). Route requests to
provision or change a global tuple through them.

**Runbook:**

1. Identify the target store for the environment in question (`STORE_ID`
   lookup as shown above, against that environment's `lfx-platform-openfga`
   service/namespace), and the environment's root project ID:
   ```bash
   # Run from an lfx-v2-argocd checkout — the values files live there, not in
   # this repo.
   ROOT_PROJECT_ID=$(yq -r '.app.rootProjectId' values/<env>/lfid-management.yaml)
   ```
2. Write the tuple:
   ```bash
   kubectl run --rm -it fga-cli --namespace <ns> --image=openfga/cli:v0.4.5 \
     --env="FGA_STORE_ID=$STORE_ID" \
     --env="FGA_API_URL=http://lfx-platform-openfga:8080" \
     --restart=Never -- tuple write \
     "team:<teamID>#member" "marketing_ops" "project:$ROOT_PROJECT_ID"
   ```
3. Verify the tuple was written by reading it back:
   ```bash
   kubectl run --rm -it fga-cli --namespace <ns> --image=openfga/cli:v0.4.5 \
     --env="FGA_STORE_ID=$STORE_ID" \
     --env="FGA_API_URL=http://lfx-platform-openfga:8080" \
     --restart=Never -- tuple read \
     --consistency HIGHER_CONSISTENCY \
     --user "team:<teamID>#member" \
     --relation "marketing_ops" \
     --object "project:$ROOT_PROJECT_ID"
   ```
   If found, the tuple was successfully written. This step uses `HIGHER_CONSISTENCY` to ensure fresh data, preventing false negatives from stale caches immediately after provisioning.
4. Verify cascade behavior with a `check` call against a relation that
   actually depends on it (not `viewer` — see the note above about
   `viewer` being public). This confirms the inheritance chain works as
   expected but does not prove the ROOT tuple itself exists — use step 3
   for that confirmation:
   ```bash
   kubectl run --rm -it fga-cli --namespace <ns> --image=openfga/cli:v0.4.5 \
     --env="FGA_STORE_ID=$STORE_ID" \
     --env="FGA_API_URL=http://lfx-platform-openfga:8080" \
     --restart=Never -- query check \
     --consistency HIGHER_CONSISTENCY \
     "user:<a-team-member>@example.com" "marketing_auditor" "project:<any-sub-project>"
   ```
   A successful check (returned `"allowed": true`) confirms that the cascade behaves as expected. Note that the CLI always exits with code 0 even when `allowed: false`, so you must inspect the response body to verify success.
5. Record what you wrote in the table below, in the same PR/change that
   requested it, so this stays the source of truth for "what global tuples
   exist in which environment."

**Currently provisioned manual tuples:**

| Tuple | Environment(s) | Purpose | Provisioned by / date |
| --- | --- | --- | --- |
| `team:<marketing-ops-teamID>#member:marketing_ops:project:<rootProjectId>` | (unconfirmed) | Grants the LF Marketing Ops team `marketing_auditor`/`campaign_manager` on every project via cascade (LFXV2-2231) | _Not yet confirmed written to any environment as of 2026-08-17 — verify before relying on it; update this row once confirmed._ |
| `team:lf-staff#member:auditor:project:<rootProjectId>` | dev, prod. **Not staging** (no team subjects on `project:4c540182-…#auditor`, verified 2026-09-15) | Global auditor population: cascades to every project (`auditor from parent`); read by the `sync-global-groups` reconciler, which grants `auditor` on every `b2b_org` (spec 044, LFXV2-3071) | Staff Support — dev 2026-06-22, prod 2026-05-04 |
| `team:lf-contractor#member:auditor:project:<rootProjectId>` | dev, prod. **Not staging** (same check) | Same population rule. LFXV2-3071 ratified staff/contractor parity (a population, not a role), so this tuple is the source both the project cascade and the `b2b_org` reconciler derive contractor read access from | Staff Support — dev 2026-06-22, prod 2026-05-04 |

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
