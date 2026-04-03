---
name: populate-jtbds
description: Populate @fgadoc:jtbd annotations in the OpenFGA model by scraping live API authorization rules from the dev Kubernetes cluster and synthesizing JTBD statements. Use when the model has new types or relations that need JTBD annotations refreshed.
license: MIT
compatibility: Requires kubectl configured against the LFX v2 platform development-environment Kubernetes cluster.
---

Populate `@fgadoc:jtbd` annotations in
`charts/lfx-platform/templates/openfga/model.yaml` by reading live API
authorization rules from the dev cluster and synthesising them into
short, action-oriented Job-to-Be-Done (JTBD) statements.

Run this skill whenever the OpenFGA model gains new types or relations and
the JTBD annotations need to be refreshed from real API usage.

## Gotchas

- `RuleSet` is a Heimdall CRD with API group `heimdall.dadrus.github.com`.
  Use the short resource name `rulesets` — the full resource name is
  `rulesets.heimdall.dadrus.github.com`.
- `[user:*]` in a define expression means "every user including anonymous"
  — it is **not** a `[user]` direct grant and must not generate a JTBD.
- Do not modify lines that are not `@fgadoc:jtbd` — `@fgadoc:alias` and
  `@fgadoc:hide` must be left exactly as they are.

## Step 1 — List all RuleSets on the dev cluster

```bash
kubectl get rulesets --all-namespaces -o json > /tmp/rulesets.json
```

## Step 2 — Extract OpenFGA checks

Parse `/tmp/rulesets.json`. For each rule whose `authorizer` contains an
`openfga_check` entry, collect:

- `ruleset` — `metadata.name` of the RuleSet (best approximation of the owning repo/service name)
- `method` — HTTP method (GET, POST, PATCH, DELETE, …)
- `route` — URL path pattern (e.g. `/committees`)
- `object` — OpenFGA object type (e.g. `project`)
- `relation` — OpenFGA relation required (e.g. `writer`)

Group the results by `<object>#<relation>` (e.g. `project#writer`).

Typical RuleSet shape (abbreviated):

```json
{
  "metadata": { "name": "lfx-v2-committee-service" },
  "spec": {
    "rules": [
      {
        "match": {
          "methods": ["POST"],
          "routes": [{ "path": "/committees" }]
        },
        "execute": [
          {
            "authorizer": "openfga_check",
            "config": {
              "values": { "object": "project:...", "relation": "writer" }
            }
          }
        ]
      }
    ]
  }
}
```

## Step 3 — Fetch OpenAPI specs for each service

For each RuleSet from step 2, scan its rules for a route whose path ends in
`openapi3.yaml`. This path is the canonical OpenAPI spec endpoint for that
service — served publicly at `https://lfx-api.dev.v2.cluster.linuxfound.info/`.

**Attempt 1 — live endpoint:**

```
GET https://lfx-api.dev.v2.cluster.linuxfound.info<openapi3.yaml path>
```

Example: if the RuleSet contains `/_committees/openapi3.yaml`, fetch
`https://lfx-api.dev.v2.cluster.linuxfound.info/_committees/openapi3.yaml`.

**Attempt 2 — GitHub fallback (if the live fetch fails or returns non-200):**

Search the `linuxfoundation` GitHub organization for `openapi3.yaml` in any
repo matching `lfx-v2-*`, using `metadata.name` of the RuleSet as the best
approximation of the repo name:

```
filename:openapi3.yaml repo:linuxfoundation/<ruleset-metadata-name>
```

Use the GitHub code search tool or API to locate the file, then read its
contents directly from the repo.

For each `method + route` pair from step 2, match it against the
OpenAPI `paths` object and extract the `summary` or `description` field.

## Step 4 — Synthesise JTBD statements

For each `<object>#<relation>` group you now have a set of API operation
descriptions. Read `references/jtbd-examples.txt` for style guidance, then
synthesise each group into one or more short, action-oriented JTBD statements.

**JTBD style rules:**
- Start with an imperative verb: *View*, *Create*, *Manage*, *Update*,
  *Add*, *Delete*, *Deploy*, *Cast*, *Submit*…
- One line, 10 words or fewer.
- Scope to what a person *wants to accomplish*, not the technical action.
- Use `&` instead of `and`.
- Do **not** use user-story format.

## Step 5 — Propose changes before writing

Before editing `model.yaml`, print a summary table of the proposed changes:

```
object#relation         | proposed JTBDs
------------------------|-------------------------------------------------------
project#writer          | Update project metadata; Manage project artifacts
meeting#organizer       | Create & manage project meetings & participants
...
```

For any relation where no OpenAPI description was found, flag it:

```
⚠  meeting#auditor — no OpenAPI description found; skipping (manual review needed)
```

Ask for confirmation before proceeding. If running non-interactively, proceed
automatically but include the summary in the final report.

## Step 6 — Write `@fgadoc:jtbd` macros into model.yaml

For each confirmed `<object>#<relation>` group:

1. Find the `define <relation>:` line within the correct `type` block.
2. **Replace** only the `# @fgadoc:jtbd` lines in the comment block
   immediately above that `define`. Leave all other lines untouched.
3. The comment format must be:

```yaml
            # @fgadoc:jtbd <statement one>
            # @fgadoc:jtbd <statement two>
            define <relation>: ...
```

Leave unchanged any `define` lines not covered by a RuleSet rule.

## Step 7 — Verify

Re-read `model.yaml` and confirm:

- Count of `@fgadoc:jtbd` lines has changed only for the affected relations.
- No `@fgadoc:alias` or `@fgadoc:hide` lines were removed or altered.
- `git diff --name-only` shows only `model.yaml` changed.

If any of these checks fail, revert and report the issue.

## Output

Report:
- How many `<object>#<relation>` groups were processed.
- How many JTBD statements were written.
- Any relations flagged for manual review (no OpenAPI description found).
