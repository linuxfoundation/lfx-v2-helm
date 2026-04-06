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

## Objects supporting role assignment

### Project

| | Project Writer | Project Auditor | Project Meeting Coordinator | Everyone |
|---|---|---|---|---|
| View project meeting count | ✅ | ✅ | | 🟡 |
| View a project | ✅ | ✅ | | 🟡 |
| View project membership key contacts | ✅ | ✅ | | |
| View project memberships & member companies | ✅ | ✅ | | |
| View project membership tiers | ✅ | ✅ | | |
| View project settings | ✅ | ✅ | | |
| Create a vote | ✅ | | | |
| Manage project membership key contacts | ✅ | | | |
| Create project committees, meetings & mailing lists | ✅ | | | |
| Update project settings | ✅ | | | |
| Create & update a project | ✅ | | | |

#### Permission Inheritance

- **Project Writer**: inherited from parent Project
- **Project Auditor**: inherited from parent Project

---

### Committee

| | Committee Member | Committee Writer | Committee Auditor | Everyone |
|---|---|---|---|---|
| View committee details, members, invites & resources | ✅ | | ✅ | 🟡 |
| View committee settings | | | ✅ | |
| Schedule a survey for a committee | | ✅ | | |
| Manage committee links & folders | | ✅ | | |
| Manage committee members, invites & applications | | ✅ | | |
| Update committee settings | | ✅ | | |
| Update & delete a committee | | ✅ | | |

#### Permission Inheritance

- **Committee Writer**: inherited from Project Writer
- **Committee Auditor**: inherited from Project Auditor, Project Meeting Coordinator

---

### Groups.io Service

| | Groups.io Service Owner | Groups.io Service Writer | Groups.io Service Auditor | Everyone |
|---|---|---|---|---|
| View a Groups.io service | | | | 🟡 |
| Create project mailing lists | ✅ | ✅ | | |
| Update & delete a Groups.io service | ✅ | ✅ | | |

#### Permission Inheritance

- **Groups.io Service Owner**: inherited from Project owner
- **Groups.io Service Writer**: inherited from Project Writer
- **Groups.io Service Auditor**: inherited from Project Auditor

---

### Mailing List

| | Mailing List Writer | Mailing List Auditor | Subscriber | Everyone |
|---|---|---|---|---|
| View & download mailing list artifacts | | | | 🟡 |
| View a mailing list & its members | | | | 🟡 |
| Add & remove mailing list members | ✅ | | | |
| Update & delete a mailing list | ✅ | | | |

#### Permission Inheritance

- **Mailing List Writer**: inherited from Groups.io Service Writer, Committee Writer
- **Mailing List Auditor**: inherited from Groups.io Service Auditor, Committee Auditor

---

### Scheduled Meeting (Individual, or recurring)

| | Organizer | Host | Participant | Everyone |
|---|---|---|---|---|

#### Permission Inheritance

- **Organizer**: inherited from Project Meeting Coordinator, Committee Writer, Project Writer

---

### Vote

| | Participant | Everyone |
|---|---|---|
| View aggregated voting results | | 🟡 |
| View a vote & its status | ✅ | 🟡 |
| Cast a vote response | ✅ | |

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
