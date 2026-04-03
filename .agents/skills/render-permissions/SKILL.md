---
name: render-permissions
description: Render PERMISSIONS.md from @fgadoc annotations in the OpenFGA model. Use after any change to model.yaml to keep the human-readable permissions reference in sync.
license: MIT
---

Read `@fgadoc` annotations from
`charts/lfx-platform/templates/openfga/model.yaml` and produce a
human-readable `PERMISSIONS.md` at the repo root.

## Gotchas

- `model.yaml` is a Helm template. The authorization model is the block
  scalar under `authorizationModel: |`. **Ignore everything outside that
  block** — Helm expressions (`{{- if ... }}`, `{{- end }}`, etc.) must
  not be parsed or evaluated.
- `[user:*]` means "every user including anonymous". It produces a
  Permission Inheritance bullet — see Step 3.
- Non-`@fgadoc` comments may appear between an `@fgadoc` annotation block
  and the `type`/`define` line it annotates (e.g. descriptive prose already
  in the file). Collect all consecutive `# @fgadoc:*` lines before a
  `type` or `define` line as that entity's annotation block, skipping any
  intervening non-`@fgadoc` comment lines.
- The `#### Permission Inheritance` section lists only **cross-type** sources
  — i.e. `<rel> from <field>` references where `<field>` resolves to a
  different type. Same-type `or <peer>` inclusions are intentionally omitted
  because they are already implicit in the ✅ columns of the table.
- The intro block before `## Entities` must be preserved exactly if
  `PERMISSIONS.md` already exists and has content there.

## Parsing `@fgadoc` annotations

Annotations are YAML-style comments placed immediately before the entity
they describe:

```
# @fgadoc:alias  Display Name   — human-readable name for a type or relation
# @fgadoc:hide                  — suppress type (whole section) or relation (column)
# @fgadoc:jtbd   Statement      — one JTBD; multiple lines allowed per relation
```

## Step 1 — Parse model.yaml

Read `charts/lfx-platform/templates/openfga/model.yaml`. Extract the
`authorizationModel: |` block and parse it as plain text.

For each `type <name>` block, extract:

| Field | How to find it |
|---|---|
| Raw type name | `type <name>` |
| Display name | `@fgadoc:alias` in preceding annotation block; else raw name |
| Hidden? | `@fgadoc:hide` in preceding annotation block |

For each `define <relation>:` line, extract:

| Field | How to find it |
|---|---|
| Raw relation name | `define <relation>:` |
| Display name | `@fgadoc:alias` in preceding annotation block; else raw name |
| Hidden? | `@fgadoc:hide` in preceding annotation block |
| JTBD list | All `@fgadoc:jtbd` lines in preceding annotation block |
| Define expression | Everything after `:` on the `define` line |
| Direct user grant? | `[user]` appears literally (not `[user:*]`) in define expression |
| Public wildcard? | `[user:*]` appears in the define expression |

## Step 2 — Build the JTBD × relation matrix

For each **visible** type (not hidden):

1. **Visible columns** — relations where `[user]` appears in the define
   expression and the relation is not hidden.
2. **JTBD rows** — all `@fgadoc:jtbd` statements across all relations of
   the type, deduplicated, in **reverse file order** (bottom-to-top).
   Include only JTBDs that belong to at least one visible column. This
   places the most general/broadly-held actions at the top and the most
   specific/privileged actions at the bottom.
3. **Cell value** — for each (JTBD, column) pair, mark ✅ if the JTBD
   appears in that column's own JTBD list **or** in the JTBD list of any
   relation transitively included via same-type `or <rel>` chains in the
   define expression.

**Worked example — `project` type:**

Relations and their defines (simplified):

```
writer:           [user] or owner or writer from parent
auditor:          [user, team#member] or writer or auditor from parent
meeting_coordinator: [user]
viewer:           [user:*] or auditor or auditor from parent   ← [user:*] only, NOT a column
```

Visible columns: `writer` (alias Manager), `auditor` (alias Staff),
`meeting_coordinator` (alias Meeting Coordinator).

`auditor` includes `writer` via `or writer` → Staff inherits all Manager JTBDs.
`viewer` is excluded (only `[user:*]`, not `[user]`).

Result (rows in reverse file order — most general first):

| Job to Be Done | Manager | Staff | Meeting Coordinator |
|---|---|---|---|
| View project legal entity settings & charter | | ✅ | |
| Create & manage project meetings & participants | ✅ | ✅ | ✅ |
| Update project metadata | ✅ | ✅ | |

## Step 3 — Build Permission Inheritance sections

For each **visible** type, for each **visible** relation, list only
**cross-type** sources:

- `<rel> from <field>` in the define expression, where `<field>` is a
  relation that links to a different type (e.g. `writer from project`
  pulls the `writer` relation from the parent `project` object).
- Parent-of-same-type inheritance (`<rel> from parent`) is cross-type
  when the parent field holds the same type — mention it explicitly.

**Do not mention** same-type `or <peer>` inclusions — these are already
visible from the ✅ columns in the table.

**Do not include verbatim OpenFGA syntax** in the output. No backtick
expressions like `` `writer from project` `` or `` `or organizer` `` should
appear anywhere in `PERMISSIONS.md`. Describe inheritance in plain English
only (e.g. "inherited from Project Manager", "inherited from parent Project").

Additionally, for any relation whose define expression contains `[user:*]`,
add a bullet using this format:

```
- **<rel display name>**: all authenticated and anonymous users inherit <Rel Display Name> access when this <Type Display Name> is configured as public
```

Omit a bullet entirely if there are no cross-type sources and no `[user:*]`
for that relation. Omit the entire `#### Permission Inheritance` sub-section
if no bullets are generated for any relation in that type.

Format for cross-type sources:

```
- **<rel display name>**: inherited from <Source Type Display Name> <Relation Display Name>
```

When multiple cross-type sources exist for one relation, list them on a
single bullet separated by commas. If a relation has both cross-type sources
and a `[user:*]` grant, emit two separate bullets.

## Step 4 — Write PERMISSIONS.md

File structure:

```markdown
<!-- Copyright The Linux Foundation and each contributor to LFX. -->
<!-- SPDX-License-Identifier: MIT -->

<intro — preserved if existing, else default below>

## Entities

### <Type display name>

| Job to Be Done | <col1> | <col2> | ... |
|---|---|---|---|
| <jtbd> | ✅ | | ✅ |

#### Permission Inheritance

- **<rel>**: inherited from ...

---
```

Use `---` as a visual divider between type sections.

For types with no visible columns (no direct `[user]` grants), write a
short prose paragraph explaining how access is inherited, and omit the
table and inheritance sub-section.

**Default intro** (use only if file is new or has no existing intro):

```markdown
This document describes the permissions model for the LFX platform.
It is generated automatically from
`charts/lfx-platform/templates/openfga/model.yaml` by the
`render-permissions` agent skill — do not edit the **Entities** section by
hand.

Run `.agents/skills/render-permissions/SKILL.md` to regenerate after any
model change.
```

## Step 5 — Verify

After writing, re-read `PERMISSIONS.md` and confirm:

- Count of `###` headings matches the number of non-hidden types.
- Every visible type with at least one visible column has a table.
- No `[user:*]`-only relation appears as a column.
- Every relation with `[user:*]` in its define has a public-access bullet in Permission Inheritance.
- JTBD rows within each table appear in reverse file order (most general action first).
- Columns within each table appear in file order (left to right matches top to bottom in the model).
- No same-type peer relations appear in Permission Inheritance bullets.
- No verbatim OpenFGA syntax (backtick expressions like `` `writer from project` ``) appears anywhere in the file.
- The intro block is unchanged (if it existed before).

Report: types rendered, total columns, total JTBD rows.
