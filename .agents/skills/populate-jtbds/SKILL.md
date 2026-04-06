---
name: populate-jtbds
description: Populate @fgadoc:jtbd annotations in the OpenFGA model by scraping live API authorization rules from the dev Kubernetes cluster and synthesizing JTBD statements. Use when the model has new types or relations that need JTBD annotations refreshed.
license: MIT
compatibility: Requires kubectl configured against the LFX v2 platform development-environment Kubernetes cluster.
---

Populate `@fgadoc:jtbd` annotations in
`charts/lfx-platform/templates/openfga/model.yaml` by reading live API
authorization rules from the dev cluster and synthesizing them into
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

## Discipline rules — read before synthesizing any JTBD

These rules are non-negotiable. Violating them produces fabricated JTBDs
that mislead users about what a role can actually do.

**1. Strict group isolation.** Every JTBD must be grounded in a route that
appears in that exact `object#relation` group in the extracted data. A route
that belongs to a *different* relation — even on the same object type — does
**not** count. Do not infer or borrow across groups.

**2. Use the `description` field, not `summary` or the path pattern.**
The OpenAPI `description` field is the source of truth for what an endpoint
does. The `summary` is often a terse label and the path pattern can be
misleading. If a route has no `description`, fall back to `summary`, and flag
it for manual review.

**3. No RuleSet checks → no JTBD.** If a relation has no routes in the
extracted groups (i.e. it is not present in `/tmp/openfga_groups.json`), leave
it with zero `@fgadoc:jtbd` lines. Do not invent plausible-sounding statements.

**4. Do not generalize write verbs.** Only use `Create & manage` or
`Update & delete` if *both* a creation route (POST) **and** an
update/delete route (PUT/PATCH/DELETE) are present in that exact group.
A single POST does not justify "manage"; a single PUT does not justify "create".

## Step 1 — Fetch RuleSets AND read model.yaml in parallel

Issue both commands simultaneously:

```bash
# Fetch all RuleSets in one call — do not call kubectl multiple times.
kubectl get rulesets --all-namespaces -o json > /tmp/rulesets.json
```

Also read `charts/lfx-platform/templates/openfga/model.yaml` at the same time
so you have the current JTBD state before any writes.

## Step 2 — Extract OpenFGA checks AND OpenAPI paths in one pass

Parse `/tmp/rulesets.json` **once** with a single Python script that produces
two output files:

- `/tmp/openfga_groups.json` — routes grouped by `<object>#<relation>`
- `/tmp/openapi_paths.json` — `{ "<ruleset-name>": "<openapi3.yaml path>" }`

For each rule, collect:

- `ruleset` — `metadata.name` of the RuleSet
- `method` — HTTP method (GET, POST, PATCH, DELETE, …)
- `route` — URL path pattern (excluding openapi3.yaml routes)
- `object` — OpenFGA object type (strip `:...` variable suffix)
- `relation` — OpenFGA relation required

Also record any route whose path ends in `openapi3.yaml` into the openapi
paths map at the same time.

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

Note: the `object` value may be a Heimdall template like
`{{- .Request.Body.committee_uid -}}` — strip everything after the `:` to get
the object type.

## Step 3 — Fetch ALL OpenAPI specs in parallel

Issue **all** live-endpoint fetches as a single parallel batch — do not fetch
them one at a time. For each entry in `/tmp/openapi_paths.json`:

```
GET https://lfx-api.dev.v2.cluster.linuxfound.info<openapi3.yaml path>
```

**GitHub fallback (for any that return non-200):**

Search the `linuxfoundation` GitHub organization for `openapi3.yaml` using the
RuleSet `metadata.name` as the repo name hint:

```
filename:openapi3.yaml repo:linuxfoundation/<ruleset-metadata-name>
```

Use GitHub code search to locate and read the file. If multiple services fail,
batch those GitHub lookups in parallel too.

The specs are large — delegate description extraction to the Task tool with
the `explore` agent to avoid consuming context. Ask it to return a compact
`METHOD /path: description` list for the routes in your groups.

For each `method + route` pair from step 2, extract the `description` field.
Fall back to `summary` only if no `description` is present.

## Step 4 — Synthesize JTBD statements

For each `<object>#<relation>` group you now have a set of API operation
descriptions. The existing `@fgadoc:jtbd` lines already in `model.yaml` are
the canonical style reference — match their grammar, verb choices, and
phrasing when writing new statements.

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
