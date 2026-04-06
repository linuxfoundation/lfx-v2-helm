<!-- Copyright The Linux Foundation and each contributor to LFX. -->
<!-- SPDX-License-Identifier: MIT -->
<!-- generated-intro
This file is generated automatically from
charts/lfx-platform/templates/openfga/model.yaml
by the render-permissions agent skill. Do not edit the sections below by hand.
Run .agents/skills/render-permissions/SKILL.md to regenerate after any model change.
-->

# LFX Self Service Platform Permissions

This document describes the permissions model for the LFX Self Service
Platform. Each section below represents an object type that supports direct
role assignment.

**Legend:** ✅ access is granted to this role · 🟡 access depends on per-item attributes/settings

## Objects supporting role assignment

### Project

| | Project Writer | Project Auditor | Project Meeting Coordinator | Everyone |
|---|---|---|---|---|
| View a project | ✅ | ✅ | | 🟡 |
| View project meeting count | ✅ | ✅ | | 🟡 |
| Create & update a project | ✅ | | | |
| View project settings | ✅ | ✅ | | |
| Update project settings | ✅ | | | |
| View project membership tiers | ✅ | ✅ | | |
| View project memberships & member companies | ✅ | ✅ | | |
| View project membership key contacts | ✅ | ✅ | | |
| Manage project membership key contacts | ✅ | | | |
| Create project committees, meetings & mailing lists | ✅ | | | |
| Create a vote | ✅ | | | |

#### Permission Inheritance

- **Project Writer**: inherited from parent Project
- **Project Auditor**: inherited from parent Project

---

### Committee

| | Committee Member | Committee Writer | Committee Auditor | Everyone |
|---|---|---|---|---|
| View committee details, members, invites & resources | ✅ | | ✅ | 🟡 |
| Update & delete a committee | | ✅ | | |
| View committee settings | | | ✅ | |
| Update committee settings | | ✅ | | |
| Manage committee members, invites & applications | | ✅ | | |
| Manage committee links & folders | | ✅ | | |
| Schedule a survey for a committee | | ✅ | | |

#### Permission Inheritance

- **Committee Writer**: inherited from Project Writer
- **Committee Auditor**: inherited from Project Auditor, Project Meeting Coordinator

---

### Groups.io Service

| | Groups.io Service Owner | Groups.io Service Writer | Groups.io Service Auditor | Everyone |
|---|---|---|---|---|
| View a Groups.io service | | | | 🟡 |
| Update & delete a Groups.io service | ✅ | ✅ | | |
| Create project mailing lists | ✅ | ✅ | | |

#### Permission Inheritance

- **Groups.io Service Owner**: inherited from Project owner
- **Groups.io Service Writer**: inherited from Project Writer
- **Groups.io Service Auditor**: inherited from Project Auditor

---

### Mailing List

| | Mailing List Writer | Mailing List Auditor | Subscriber | Everyone |
|---|---|---|---|---|
| View a mailing list & its members | | | | 🟡 |
| Update & delete a mailing list | ✅ | | | |
| Add & remove mailing list members | ✅ | | | |
| View & download mailing list artifacts | | | | 🟡 |

#### Permission Inheritance

- **Mailing List Writer**: inherited from Groups.io Service Writer, Committee Writer
- **Mailing List Auditor**: inherited from Groups.io Service Auditor, Committee Auditor

---

### Vote

| | Participant | Everyone |
|---|---|---|
| View a vote & its status | ✅ | 🟡 |
| Cast a vote response | ✅ | |
| View aggregated voting results | | 🟡 |

---

### Vote Response

| | Voter |
|---|---|
| Update your vote response | ✅ |

---

### Survey

| | Participant | Everyone |
|---|---|---|
| View a survey | ✅ | 🟡 |

---

### Survey Response

| | Respondent |
|---|---|
