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
- `@fgadoc:hide` objects and relations are **not** excluded from JTBD
  processing. If a hidden type or relation has matching RuleSet routes,
  synthesize and write JTBDs for it exactly as you would for a visible one.
- Some object types have relations that are enforced by the **Query Service**
  rather than Heimdall RuleSets. The Query Service reads `access_check_object`
  and `access_check_relation` fields embedded in indexed documents to determine
  which OpenFGA object and relation to check — typically delegating to a parent
  object type (e.g., a recording delegates its `viewer` check to the parent
  `v1_past_meeting`). These relations will have zero RuleSet entries; their
  JTBDs are synthesized from indexer contracts in Step 2b.
- An indexed object type may not appear in `model.yaml` at all (e.g.,
  `v1_meeting_registrant`). Step 2b writes JTBDs onto the `access_check_object`
  type's relation in `model.yaml`, **not** onto the indexed type itself.

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

**3. No coverage from either source → no JTBD.** If a relation has no routes
in `/tmp/openfga_groups.json` (RuleSets) **and** no entry in
`/tmp/query_service_groups.json` (indexer contracts), leave it with zero
`@fgadoc:jtbd` lines. Do not invent plausible-sounding statements.
A `@fgadoc:hide` annotation does **not** exempt an object or relation from this
rule.

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

## Step 2b — Discover Query Service authorization from indexer contracts

In parallel with or immediately after Step 2, fetch all indexer contract
documents from GitHub to discover which `object#relation` pairs are enforced
by the Query Service rather than Heimdall.

**Search for all contracts:**

```
filename:indexer-contract.md org:linuxfoundation
```

Fetch every result's file contents via the GitHub API in a single parallel
batch (use the `repo` and `path` from each search result).

**Parse each contract** to extract, for every resource type section:

- `object_type` — from the `**Object type:** \`...\`` line
- `access_check_object` — from the `Access Control (IndexingConfig)` table row
- `access_check_relation` — from the same table

Strip the `:{...}` suffix from `access_check_object` to get the **delegate
type** (e.g., `v1_past_meeting:{meeting_and_occurrence_id}` →
`v1_past_meeting`).

A resource type contributes a Query Service entry when its `access_check_object`
delegate type **differs** from its own `object_type` (meaning the Query Service
delegates authorization upward to a parent object).

Write `/tmp/query_service_groups.json` in this shape:

```json
{
  "v1_past_meeting#viewer": [
    {
      "indexed_type": "v1_past_meeting_recording",
      "human_label": "past meeting recordings"
    },
    {
      "indexed_type": "v1_past_meeting_transcript",
      "human_label": "past meeting transcripts"
    }
  ]
}
```

The key is `<delegate_type>#<access_check_relation>` — the OpenFGA
`object#relation` that the Query Service actually checks. The `human_label` is
a short plural noun derived from the `object_type` by stripping the leading
`v1_` prefix and replacing underscores with spaces (e.g.,
`v1_past_meeting_recording` → `past meeting recordings`).

**Union with RuleSet groups:** When generating JTBDs in Step 4, treat entries
in `/tmp/query_service_groups.json` as additional coverage for the delegate
`object#relation`. A relation that has RuleSet entries for write operations but
a query-service entry for read will receive JTBDs from both sources.

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
descriptions (from RuleSets) and/or a list of indexed child types (from indexer
contracts). The existing `@fgadoc:jtbd` lines already in `model.yaml` are the
canonical style reference — match their grammar, verb choices, and phrasing
when writing new statements.

**For RuleSet-sourced groups:** synthesize from the OpenAPI operation
descriptions as before.

**For Query Service-sourced groups:** synthesize one JTBD per `human_label`
entry, scoped to viewing that child resource. For example, an entry with
`human_label: "past meeting recordings"` on `v1_past_meeting#viewer` produces:

```
View past meeting recordings
```

If a relation has entries from **both** sources, include all JTBDs — RuleSet
statements first, then Query Service statements.

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
   - For RuleSet-sourced groups, `<object>` is the type block to target.
   - For Query Service-sourced groups, `<object>` is the **delegate type**
     (e.g., `v1_past_meeting`), not the indexed type. Write onto the delegate
     type's relation block even if the indexed type also exists in `model.yaml`.
2. **Replace** only the `# @fgadoc:jtbd` lines in the comment block
   immediately above that `define`. Leave all other lines untouched.
3. The comment format must be:

```yaml
            # @fgadoc:jtbd <statement one>
            # @fgadoc:jtbd <statement two>
            define <relation>: ...
```

Leave unchanged any `define` lines not covered by either source.

## Step 7 — Fix indentation

After writing JTBDs, scan every `# @fgadoc:` comment and `define` line in the
file for indentation consistency within each `type` block. All relation-level
lines must use the same indent (12 spaces inside the `authorizationModel`
literal block). Any line with a different number of leading spaces — whether
introduced by this run or pre-existing — must be corrected to match its
siblings.

Use ripgrep to detect outliers:

```bash
rg -n "^ *# @fgadoc:|^ *define " charts/lfx-platform/templates/openfga/model.yaml \
  | rg -v "^[0-9]+:            [^ ]|^[0-9]+:        [^ ]"
```

No output means all lines are correctly aligned.

## Step 8 — Verify

Re-read `model.yaml` and confirm:

- Count of `@fgadoc:jtbd` lines has changed only for the affected relations.
- No `@fgadoc:alias` or `@fgadoc:hide` lines were removed or altered.
- `git diff --name-only` shows only `model.yaml` changed.

If any of these checks fail, revert and report the issue.

## Output

Report:
- How many `<object>#<relation>` groups were processed (broken down by source:
  RuleSets vs. indexer contracts vs. both).
- How many JTBD statements were written.
- Any relations flagged for manual review (no OpenAPI description found).
