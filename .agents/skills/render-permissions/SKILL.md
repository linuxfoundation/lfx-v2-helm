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
- `[user:*]` means "every user including anonymous". It produces an
  **Everyone** column in the table — see Step 2.
- Non-`@fgadoc` comments may appear between an `@fgadoc` annotation block
  and the `type`/`define` line it annotates (e.g. descriptive prose already
  in the file). Collect all consecutive `# @fgadoc:*` lines before a
  `type` or `define` line as that entity's annotation block, skipping any
  intervening non-`@fgadoc` comment lines.
- The `#### Permission Inheritance` section lists only **cross-type** sources
  — i.e. `<rel> from <field>` references where `<field>` resolves to a
  different type. Same-type `or <peer>` inclusions are intentionally omitted
  because they are already implicit in the ✅ / 🟡 columns of the table.
- The intro block before `## Objects supporting role assignment` must be
  preserved exactly if `PERMISSIONS.md` already exists and has content there.
- The `<!-- generated-intro -->` comment block at the top must be preserved
  exactly if `PERMISSIONS.md` already exists.

## Parsing `@fgadoc` annotations

Annotations are YAML-style comments placed immediately before the entity
they describe:

```
# @fgadoc:alias    Display Name   — human-readable name for a type or relation
# @fgadoc:hide                    — suppress type (whole section) or relation (column)
# @fgadoc:jtbd     Statement      — one JTBD; multiple lines allowed per relation
# @fgadoc:collapse <target_type>  — collapse this type's JTBDs into <target_type>'s section
```

## Step 1 — Parse model.yaml

Read `charts/lfx-platform/templates/openfga/model.yaml`. Extract the
`authorizationModel: |` block and parse it as plain text.

For each `type <name>` block, extract:

| Field | How to find it |
|---|---|
| Raw type name | `type <name>` |
| Display name | `@fgadoc:alias` in preceding annotation block; else raw name in Title Case with underscores replaced by spaces |
| Hidden? | `@fgadoc:hide` in preceding annotation block |
| Collapse target | `@fgadoc:collapse <target_type>` in preceding annotation block (raw type name of the target) |

A type with `@fgadoc:collapse <target_type>` is treated as **collapsed**: it
is hidden (no `###` section is generated for it) and its JTBDs are folded
into the `<target_type>` section. See Step 2b for how collapsed JTBDs are
incorporated.

For each `define <relation>:` line, extract:

| Field | How to find it |
|---|---|
| Raw relation name | `define <relation>:` |
| Display name | `@fgadoc:alias` in preceding annotation block; else raw name in Title Case with underscores replaced by spaces |
| Hidden? | `@fgadoc:hide` in preceding annotation block |
| JTBD list | All `@fgadoc:jtbd` lines in preceding annotation block |
| Define expression | Everything after `:` on the `define` line |
| Direct user grant? | `[user]` appears literally (not `[user:*]`) in define expression |
| Public wildcard? | `[user:*]` appears in the define expression |

## Step 2 — Build the JTBD × relation matrix

### 2a — Determine visible columns

For each **visible** type (not hidden), determine **visible named-role
columns** — relations where `[user]` appears literally (not `[user:*]`) in
the define expression **and** the relation is not hidden.

Additionally, if **any** relation in the type has `[user:*]` in its define
expression (even a hidden relation), include an **Everyone** column as the
**rightmost** column. The Everyone column is special: it uses the 🟡 marker
instead of ✅, and it collects JTBDs from **all relations** that contain
`[user:*]`.

### 2b — Determine JTBD rows

**Include ALL `@fgadoc:jtbd` statements** across ALL relations of the type,
deduplicated. Do **not** filter out JTBDs whose relation has no visible
column — they still appear as rows (they may have a 🟡 in the Everyone
column).

**Collapsed types:** For each type C whose `@fgadoc:collapse` names this
type as the target, include C's JTBDs in this type's JTBD pool as well.
To determine ✅ placement for a collapsed JTBD:

1. For each relation `R_c` on C that carries the JTBD, inspect R_c's define
   expression for a `<rel> from <field>` term where `<field>` resolves to
   this (target) type.
2. The `<rel>` identified in step 1 is the corresponding relation on the
   target type. Build its **full upward reachability set** on the target
   type (same algorithm as Step 2c) to determine which columns get ✅.
3. If R_c's define has no such term (no `<rel> from <field>` pointing to
   this type), the collapsed JTBD still appears as a row but no column
   gets ✅ for it.

Collapsed JTBDs are **interleaved** with the target type's own JTBDs using
the same row-ordering rules below — they are not appended as a separate
group.

**Row ordering:** Sort JTBD rows using the following priority rules, applied
in order:

1. **Base object first.** JTBDs that describe viewing, reading, or accessing
   the object itself (the type; may be phrased as "details", "definition",
   or just the type name) come first. If viewing the base object is bundled
   with other operations in a single JTBD (e.g. "View a meeting & its
   attachments"), it still sorts first — especially when it is the JTBD that
   carries the 🟡 Everyone marker.

2. **Settings next.** JTBDs that refer to "settings" of the object come
   immediately after the base-object group.

3. **Attributes in Read → Update → Delete order.** For each logical group of
   related attributes or sub-resources (e.g. members, invites, links), sort
   Read operations before Update/Create before Delete. Group related
   attributes together so that Read/Update/Delete for the same thing are
   adjacent.

4. **Child resource creation last.** JTBDs that create child resources of
   another type come last. If creating a child of the **same** type is
   allowed, list that first among the child-creation group. Otherwise order
   child-creation JTBDs by the order their target types appear in model.yaml.

### 2c — Compute cell values

**OpenFGA semantics primer:** When relation B's define says `or A` (B
includes A), it means *anyone who has relation A also satisfies relation B*.
In other words, A ⊆ B — A is the more privileged role. A writer who is
included in auditor (`auditor: ... or writer`) automatically has auditor
access too, because writers are a subset of auditors.

**Consequence for columns:** A column represents a role a user is directly
assigned to. The column should show ✅ for every action that role can
perform — including actions inherited *upward* from any relation that
includes this role.

For each (JTBD, column) pair:

**For a named-role column** (has `[user]`):

Build the **upward reachability set** for the column's relation: starting
from that relation, find every other relation in the same type whose define
expression contains `or <this-relation>` (directly or transitively). Collect
the JTBD lists from the starting relation itself **and** every relation in
the upward reachability set. If any of those JTBD lists contains the target
JTBD, mark ✅.

Do **not** traverse downward (i.e., do not add JTBDs from relations listed
via `or <peer>` inside this column's own define — those are relations this
role subsumes, not roles that subsume this role).

**For the Everyone column** (`[user:*]`):

For each relation R whose define contains `[user:*]`, build R's own upward
reachability set using the same rule. Mark 🟡 if the JTBD appears in the
JTBD list of R itself **or** any relation in R's upward reachability set.

**Worked example — `project` type:**

Relations and their defines (simplified):

```
writer:           [user] or owner or writer from parent
                  JTBDs: Create a vote, Manage key contacts, Create committees/meetings/lists,
                         Update project settings, Create & update a project

auditor:          [user, team#member] or writer or auditor from parent
                  JTBDs: View project settings, View membership tiers,
                         View memberships & member companies, View membership key contacts

meeting_coordinator: [user]
                  JTBDs: (none)

viewer:           [user:*] or auditor or auditor from parent
                  JTBDs: View a project, View project meeting count
```

Named-role columns: `writer`, `auditor`, `meeting_coordinator`.
Everyone column: yes (`viewer` has `[user:*]`).

**Upward reachability:**

- `writer`: which relations say `or writer`? → `auditor` does. Which say `or auditor`? → `viewer` does (but viewer is not a named-role column). So writer's upward set = {auditor, viewer}.
  Writer column JTBDs = writer's own ∪ auditor's own ∪ viewer's own = all JTBDs.

- `auditor`: which relations say `or auditor`? → `viewer` does. Auditor's upward set = {viewer}.
  Auditor column JTBDs = auditor's own ∪ viewer's own = auditor JTBDs + viewer JTBDs.

- `meeting_coordinator`: nothing includes meeting_coordinator. Upward set = {}.
  Meeting coordinator column JTBDs = (none) → all cells empty.

- Everyone (`viewer` has `[user:*]`): viewer's upward set = {} (nothing includes viewer).
  Everyone JTBDs = viewer's own only = {View a project, View project meeting count}.

Result table (JTBD rows ordered by semantic priority — base object first, then settings, then attributes, then child resource creation):

| | Project Writer | Project Auditor (full read) | Project Meeting Coordinator | Everyone |
|---|---|---|---|---|
| View a project | ✅ | ✅ | | 🟡 |
| View project meeting count | ✅ | ✅ | | 🟡 |
| View project membership key contacts | ✅ | ✅ | | |
| View project memberships & member companies | ✅ | ✅ | | |
| View project membership tiers | ✅ | ✅ | | |
| View project settings | ✅ | ✅ | | |
| Create a vote | ✅ | | | |
| Manage project membership key contacts | ✅ | | | |
| Create project committees, meetings & mailing lists | ✅ | | | |
| Update project settings | ✅ | | | |
| Create & update a project | ✅ | | | |

Note: "View a project" and "View project meeting count" appear even though
they come from `viewer` which has no `[user]` grant — all JTBDs are always
shown as rows.

Note: write JTBDs ("Create a vote" etc.) do NOT appear in the Everyone
column because `viewer` does not include `writer` — the chain is
`viewer → auditor → writer` only when you are a privileged user, not when
you are anonymous. The upward reachability for viewer stops at viewer
itself (nothing includes viewer).

### 2d — Omit the Everyone column only when no type-level relation has `[user:*]`

If no relation in the type has `[user:*]` in its define expression, omit
the Everyone column entirely. The Everyone column is ALWAYS the rightmost.

## Step 3 — Build Permission Inheritance sections

For each **visible** type, for each **named-role relation** (has `[user]`,
not hidden), emit a bullet only when the relation's own define expression
contains one or more **direct** `<rel> from <field>` terms where `<field>`
resolves to a **different** type (i.e. a field whose type annotation is not
the current type).

Rules:

- Only examine the define expression of the relation itself — do **not**
  follow `or <peer>` chains to discover cross-type sources that belong to
  a peer relation. Each relation's bullet describes only what is written
  directly in that relation's define.
- Parent-of-same-type (`<rel> from parent`) counts as cross-type when
  `parent` holds the current type (i.e. it is a recursive parent link) —
  mention it as "inherited from parent \<Type Display Name\>".
- **Do not** emit a bullet for `[user:*]` public-access — this is already
  communicated by the Everyone column in the table.
- **Do not mention** same-type `or <peer>` inclusions — these are already
  visible from the ✅ columns in the table.
- Omit a bullet entirely if the relation has no direct cross-type sources.
- Omit the entire `#### Permission Inheritance` sub-section if no bullets
  are generated for any relation in that type.

**Do not include verbatim OpenFGA syntax** in the output. No backtick
expressions like `` `writer from project` `` or `` `or organizer` `` should
appear anywhere in `PERMISSIONS.md`. Describe inheritance in plain English
only (e.g. "inherited from Project Writer", "inherited from parent Project").

Format:

```
- **<rel display name>**: inherited from <Source Type Display Name> <Relation Display Name>
```

When multiple direct cross-type sources exist for one relation, list them on
a single bullet separated by commas.

## Step 4 — Write PERMISSIONS.md

File structure:

```markdown
<!-- Copyright The Linux Foundation and each contributor to LFX. -->
<!-- SPDX-License-Identifier: MIT -->
<!-- generated-intro
This file is generated automatically from
charts/lfx-platform/templates/openfga/model.yaml
by the render-permissions agent skill. Do not edit the sections below by hand.
Run .agents/skills/render-permissions/SKILL.md to regenerate after any model change.
-->

# LFX Self Service Platform Permissions

<intro — preserved if existing, else default below>

## Objects supporting role assignment

### <Type display name>

| | <col1> | <col2> | ... | Everyone |
|---|---|---|---|---|
| <jtbd> | ✅ | | ✅ | 🟡 |

#### Permission Inheritance

- **<rel>**: inherited from ...

---
```

Use `---` as a visual divider between type sections.

For types with no visible columns and no Everyone column (no direct `[user]`
or `[user:*]` grants at all), write a short prose paragraph explaining how
access is inherited, and omit the table and inheritance sub-section.

**Table header row:** The first cell of the header row is **blank** (no
"Job to Be Done" text). Columns follow the ordering rule below, with
Everyone always last.

**Column ordering rule:** Within the named-role columns, apply this sort:

1. **owner** (if present) — leftmost
2. **writer** (if present)
3. **auditor** (if present)
4. Any remaining columns whose raw relation name does **not** match
   `member`, `participant`, or `subscriber` — in file order among themselves
5. **member**, **participant**, **subscriber** (whichever are present) —
   rightmost among named-role columns, in file order among themselves
6. **Everyone** — always the absolute rightmost column

**Default intro** (use only if file is new or has no existing intro after
the `<!-- generated-intro ... -->` block):

```markdown
This document describes the permissions model for the LFX Self Service
Platform. Each section below represents an object type that supports direct
role assignment.
```

**Preserving the intro:** The `<!-- generated-intro ... -->` comment block and
the H1 heading are always re-written. Everything between the H1 and the
`## Objects supporting role assignment` heading is the intro and must be
preserved if it already exists.

## Step 5 — Verify

After writing, re-read `PERMISSIONS.md` and confirm:

- Count of `###` headings matches the number of non-hidden, non-collapsed types.
- Collapsed types (those with `@fgadoc:collapse`) have no `###` section of their own; their JTBDs appear in their target type's section.
- Collapsed JTBDs are interleaved with the target type's own JTBDs (not appended as a separate block).
- Every visible type with at least one visible column or Everyone column has a table.
- No `[user:*]`-only relation appears as a named-role column.
- Every type with at least one `[user:*]` relation has an Everyone column.
- Every relation with `[user:*]` in its define does NOT get a public-access bullet (the Everyone column covers this).
- Permission Inheritance bullets only appear for named-role relations (has `[user]`, not hidden) with direct cross-type `<rel> from <field>` terms in their own define — no peer-chain traversal.
- JTBD rows within each table follow the semantic ordering rule: base object first, settings next, attributes in Read → Update → Delete order, child resource creation last.
- ALL JTBDs from ALL relations of a type appear as rows (including viewer/public JTBDs).
- Named-role columns follow the ordering rule: owner → writer → auditor → other (file order) → member/participant/subscriber (file order) → Everyone rightmost.
- The Everyone column is always rightmost.
- Writer columns show ✅ for auditor JTBDs (because auditor includes writer, so writers have auditor access).
- Auditor columns do NOT show ✅ for writer-only JTBDs (auditors are not writers).
- The Everyone column shows 🟡 only for JTBDs from the `[user:*]` relation's own upward reachability set (not from privileged roles that the [user:*] relation happens to include downward).
- The table header first cell is blank (no "Job to Be Done" text).
- No same-type peer relations appear in Permission Inheritance bullets.
- No verbatim OpenFGA syntax (backtick expressions like `` `writer from project` ``) appears anywhere in the file.
- The `<!-- generated-intro ... -->` block is present at the top.
- The H1 `# LFX Self Service Platform Permissions` is present.
- The `## Objects supporting role assignment` heading is used (not `## Entities`).
- The intro block is unchanged (if it existed before).

Report: types rendered, total columns (excluding Everyone), total JTBD rows.
