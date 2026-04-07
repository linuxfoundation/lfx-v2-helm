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
- The intro block before `## Object types` must be preserved exactly if
  `PERMISSIONS.md` already exists and has content there.
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
| Indirect-only? | Does NOT have `[user]` or `[user:*]`, AND has at least one `<rel> from <field>` term where `<field>` resolves to a different type |

## Step 2 — Build the JTBD × relation matrix

### 2a — Determine visible columns

For each **visible** type (not hidden), determine two sets of visible columns:

**Direct-grant columns** — relations where `[user]` appears literally (not
`[user:*]`) in the define expression **and** the relation is not hidden.

**Indirect-only columns** — relations that are indirect-only (no `[user]` or
`[user:*]`, has at least one cross-type `<rel> from <field>` term) **and**
are not hidden **and** would have at least one ✅ cell (i.e. their reachable
JTBD pool is non-empty — see Step 2c for how to compute this). These columns
represent roles that can only be assigned by granting access on a foreign
object, not directly on this object. Their header text is **italicized** in
the Markdown table (wrap the display name in `*...*`).

Additionally, if **any** relation in the type has `[user:*]` in its define
expression (even a hidden relation), include an ***Everyone*** column as the
**rightmost** column. The Everyone column header is always italicized (`*Everyone*`).
It is special: it uses the 🟡 marker instead of ✅, and it collects JTBDs
from **all relations** that contain `[user:*]`.

### 2b — Determine JTBD rows

**Include ALL `@fgadoc:jtbd` statements** across ALL relations of the type,
deduplicated. Do **not** filter out JTBDs whose relation has no visible
column — they still appear as rows (they may have a 🟡 in the Everyone
column).

**Collapsed types:** For each type C whose `@fgadoc:collapse` names this
type as the target, include C's JTBDs in this type's JTBD pool as well.
To determine ✅ placement for a collapsed JTBD:

1. For each relation `R_c` on C that carries the JTBD, build the full set
   of **contributing relations on C**: start with R_c itself, then for
   every `or <peer>` in R_c's define, add that peer — and recurse into
   each peer's define for further `or <peer>` terms (downward inclusion
   expansion within type C only; do NOT expand `or <peer>` on the target
   type here).

2. For each contributing relation on C, collect every `<rel> from <field>`
   term in that relation's define where `<field>` resolves to the target
   type. "Resolves to the target type" means the field's declared type
   (from the `define <field>: [<type>]` line on C) is the target type.
   This includes fields whose type is `[<target_type>]` directly (e.g.
   `define past_meeting: [v1_past_meeting]`) **and** fields typed as
   `[<target_type>]` via a different name (e.g.
   `define past_meeting_for_participant_view: [v1_past_meeting]`).

   For each such `<field>`, determine whether it is **unconditional** or
   **conditional**:

   - **Unconditional**: the field is the primary parent link — it is the
     field that the majority of peer relations on C use in their own
     `from` expressions (e.g. `past_meeting` is used by `writer`,
     `auditor`, `host`, `participant`). Cross-type sources via an
     unconditional field yield **✅**.
   - **Conditional**: the field is a secondary settable pointer whose
     define is a bare `[<type>]` with no `or` terms, and it is *not* the
     primary parent field described above (e.g.
     `past_meeting_for_participant_view`, `past_meeting_for_attendee_view`,
     `past_meeting_for_host_view`, `vote_for_participant_result_access`).
     These fields are only populated when a per-object setting enables
     that group's access. Cross-type sources via a conditional field yield
     **🟡** instead of ✅ — place the marker in the same column that ✅
     would have occupied.

3. Each `<rel>` identified in step 2 names a relation on the target type.
   Build its **full upward reachability set** on the target type (same
   algorithm as Step 2c) to determine which columns get the marker (✅ or
   🟡 as determined in step 2).

   **Propagation rule for 🟡:** if a source relation yields 🟡, all
   columns in its upward reachability set also get 🟡 (not ✅) for this
   JTBD — unless those columns already have ✅ from a different
   unconditional source.

4. If no contributing relation on C has any `<rel> from <field>` term
   pointing to the target type (after the full expansion in steps 1–2),
   the collapsed JTBD still appears as a row but no column gets ✅ or 🟡
   for it.

**Example** (`v1_past_meeting_summary` collapsed into `v1_past_meeting`):

`viewer` on `v1_past_meeting_summary` carries the JTBD "View a past
meeting summary". Its define is:
```
[user:*] or writer or auditor
  or invitee from past_meeting_for_participant_view
  or attendee from past_meeting_for_attendee_view
  or host from past_meeting_for_host_view
```
Step 1 expands downward `or` peers of `viewer` on the collapsed type:
- `writer` (define: `organizer from past_meeting`) → field `past_meeting`
- `auditor` (define: `auditor from past_meeting`) → field `past_meeting`

`past_meeting` is the **primary parent field** (used by `writer`, `auditor`,
`host`, `participant` on `v1_past_meeting_summary`) → **unconditional** → ✅.

Direct `<rel> from <field>` on `viewer` itself:
- `invitee from past_meeting_for_participant_view`
- `attendee from past_meeting_for_attendee_view`
- `host from past_meeting_for_host_view`

These three fields (`past_meeting_for_*_view`) are secondary settable
pointers (bare `[v1_past_meeting]`, no `or` terms, not the primary parent
field) → **conditional** → 🟡.

Step 3: build upward reachability on `v1_past_meeting` for each source `<rel>`:
- `organizer` (unconditional) → upward set includes `auditor`. *Organizer*
  and *Auditor* indirect-only columns get ✅.
- `auditor` (unconditional) → upward set = {}. *Auditor* column gets ✅.
- `invitee` (conditional) → upward set: `viewer` (not a column). Invitee
  direct-grant column gets 🟡.
- `attendee` (conditional) → Attendee column gets 🟡.
- `host` (conditional) → Host column gets 🟡.

Result: "View a past meeting summary" row shows ✅ for *Organizer* and
*Auditor*, 🟡 for Host, Invitee, Attendee, and 🟡 for Everyone (because
`[user:*]` is in the viewer define of the collapsed type).

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

**Consequence for columns:** A column represents a role. For direct-grant
columns, a user is directly assigned to the role. For indirect-only columns,
a user reaches the role via a foreign object. In both cases, the column
should show ✅ for every action that role can perform — including actions
inherited *upward* from any relation that includes this role.

For each (JTBD, column) pair:

**For a direct-grant column** (has `[user]`) **or an indirect-only column**:

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

**Everyone column for collapsed JTBDs:** If a collapsed type C has a
relation R_c whose define contains `[user:*]`, and R_c carries (or its
upward reachability set carries) the collapsed JTBD, mark 🟡 for that JTBD
in the target type's Everyone column. The target type's Everyone column
must already exist (i.e. the target type itself has at least one relation
with `[user:*]`); if it does not, the 🟡 is still shown — the Everyone
column is added even if it would otherwise be absent on the target type,
because the collapsed type contributes a `[user:*]` relation.

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

| | Project Writer | Project Auditor (full read) | Project Meeting Coordinator | *Everyone* |
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

If no relation in the type **or any type that collapses into it** has
`[user:*]` in its define expression, omit the Everyone column entirely.
The Everyone column is ALWAYS the rightmost.

## Step 3 — Build Permission Inheritance sections

For each **visible** type, for each **direct-grant relation** (has `[user]`,
not hidden) **and each indirect-only column**, emit a bullet only when the
relation's own define expression contains one or more **direct**
`<rel> from <field>` terms where `<field>` resolves to a **different** type
(i.e. a field whose type annotation is not the current type).

Indirect-only columns always have at least one cross-type source by
definition, so they will always produce a bullet. Their bullet uses the same
format as direct-grant bullets — italicize the relation display name to match
the italicized column header:

```
- ***<rel display name>***: inherited from <Source Type Display Name> <Relation Display Name>
```

Direct-grant bullet format (unchanged):

```
- **<rel display name>**: inherited from <Source Type Display Name> <Relation Display Name>
```

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

## Object types

### <Type display name>

| | <col1> | <col2> | ... | *Everyone* |
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

**Column ordering rule:** Apply this sort across all columns:

1. **Indirect-only columns** (italicized) — leftmost of all, ordered by
   descending privilege: **owner** → **writer** → **organizer** → **auditor**
   → any remaining (file order among themselves)
2. **owner** (if present, direct-grant)
3. **writer** (if present, direct-grant)
4. **auditor** (if present, direct-grant)
5. Any remaining direct-grant columns whose raw relation name does **not**
   match `member`, `participant`, or `subscriber` — in file order among
   themselves
6. **member**, **participant**, **subscriber** (whichever are present,
   direct-grant) — rightmost among direct-grant columns, in file order
   among themselves
7. **Everyone** — always the absolute rightmost column

**Default intro** (use only if file is new or has no existing intro after
the `<!-- generated-intro ... -->` block):

```markdown
This document describes the permissions model for the LFX Self Service
Platform. Each section below represents an object type that supports direct
role assignment.

## Legend

- "**Role Name**" column headings are assignable roles for this object type (may also be inherited; see lists below tables)
- "**_Italicized Role Name_**" headings are implicit or inherited roles (_not_ directly assignable on this object type)
- ✅ access is granted to this role to all objects of this type
- 🟡 access is conditional on per-object settings
```

**Preserving the intro:** The `<!-- generated-intro ... -->` comment block and
the H1 heading are always re-written. Everything between the H1 and the
`## Object types` heading is the intro and must be preserved if it already
exists.

## Step 5 — Verify

After writing, re-read `PERMISSIONS.md` and confirm:

- Count of `###` headings matches the number of non-hidden, non-collapsed types.
- Collapsed types (those with `@fgadoc:collapse`) have no `###` section of their own; their JTBDs appear in their target type's section.
- Collapsed JTBDs are interleaved with the target type's own JTBDs (not appended as a separate block).
- For each collapsed JTBD, ✅ placement uses the full expansion algorithm (Step 2b): downward `or` peer expansion on the collapsed type, then cross-type `<rel> from <field>` resolution (including fields typed as the target type under a different name), then upward reachability on the target type.
- Collapsed JTBDs sourced via a **conditional** field (secondary settable pointer, not the primary parent field) show 🟡 rather than ✅ for the corresponding columns and their upward reachability set — unless those columns already have ✅ from a separate unconditional source.
- Every visible type with at least one visible column or Everyone column has a table.
- No `[user:*]`-only relation appears as a direct-grant or indirect-only column.
- Every type with at least one `[user:*]` relation has an *Everyone* column (italicized header).
- Every relation with `[user:*]` in its define does NOT get a public-access bullet (the Everyone column covers this).
- Indirect-only columns appear leftmost, before all direct-grant columns, in file order among themselves.
- Indirect-only column headers are italicized (e.g. `*Writer*`, `*Auditor*`).
- Indirect-only columns with zero ✅ cells are omitted entirely.
- Permission Inheritance bullets appear for both direct-grant relations (has `[user]`, not hidden) and indirect-only columns, when they have direct cross-type `<rel> from <field>` terms in their own define — no peer-chain traversal.
- Indirect-only bullets use bold-italic name (e.g. `- ***Auditor***: inherited from ...`); direct-grant bullets use bold name (e.g. `- **Writer**: inherited from ...`).
- JTBD rows within each table follow the semantic ordering rule: base object first, settings next, attributes in Read → Update → Delete order, child resource creation last.
- ALL JTBDs from ALL relations of a type appear as rows (including viewer/public JTBDs).
- Column ordering rule applied: indirect-only (owner → writer → organizer → auditor → other file order) → owner → writer → auditor → other direct-grant (file order) → member/participant/subscriber (file order) → *Everyone* rightmost.
- The *Everyone* column header is italicized.
- The *Everyone* column is always rightmost.
- Writer columns show ✅ for auditor JTBDs (because auditor includes writer, so writers have auditor access).
- Auditor columns do NOT show ✅ for writer-only JTBDs (auditors are not writers).
- The *Everyone* column shows 🟡 only for JTBDs from the `[user:*]` relation's own upward reachability set (not from privileged roles that the [user:*] relation happens to include downward).
- The table header first cell is blank (no "Job to Be Done" text).
- No same-type peer relations appear in Permission Inheritance bullets.
- No verbatim OpenFGA syntax (backtick expressions like `` `writer from project` ``) appears anywhere in the file.
- The `<!-- generated-intro ... -->` block is present at the top.
- The H1 `# LFX Self Service Platform Permissions` is present.
- The `## Object types` heading is used (not `## Objects supporting role assignment` or `## Entities`).
- The intro block is unchanged (if it existed before).

Report: types rendered, total columns (excluding Everyone), total JTBD rows.
