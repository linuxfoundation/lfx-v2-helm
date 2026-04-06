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

## Legend

- "**Role Name**" column headings are assignable roles for this object type (may also be inherited; see lists below tables)
- "**_Italicized Role Name_**" headings are implicit or inherited roles (_not_ directly assignable on this object type)
- ✅ access is granted to this role to all objects of this type
- 🟡 access is conditional based on per-object settings

## Object types

### Project

| | Project Writer | Project Auditor | Project Meeting Coordinator | *Everyone* |
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

#### Permission Inheritance

- **Project Writer**: inherited from parent Project
- **Project Auditor**: inherited from parent Project

---

### Committee

| | Committee Writer | Committee Auditor | Committee Member | *Everyone* |
|---|---|---|---|---|
| View committee details, members, invites & resources | | ✅ | ✅ | 🟡 |
| View committee settings | | ✅ | | |
| Update committee settings | ✅ | | | |
| Manage committee members, invites & applications | ✅ | | | |
| Manage committee links & folders | ✅ | | | |
| Update & delete a committee | ✅ | | | |
| Schedule a survey for a committee | ✅ | | | |

#### Permission Inheritance

- **Committee Writer**: inherited from Project Writer
- **Committee Auditor**: inherited from Project Auditor, Project Meeting Coordinator

---

### Groups.io Service

| | Groups.io Service Owner | Groups.io Service Writer | Groups.io Service Auditor | *Everyone* |
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

| | Mailing List Writer | Mailing List Auditor | Subscriber | *Everyone* |
|---|---|---|---|---|
| View a mailing list & its members | | | | 🟡 |
| View & download mailing list artifacts | | | | 🟡 |
| Add & remove mailing list members | ✅ | | | |
| Update & delete a mailing list | ✅ | | | |

#### Permission Inheritance

- **Mailing List Writer**: inherited from Groups.io Service Writer, Committee Writer
- **Mailing List Auditor**: inherited from Groups.io Service Auditor, Committee Auditor

---

### Scheduled Meeting

| | *Organizer* | *Auditor* | Host | Participant | *Everyone* |
|---|---|---|---|---|---|
| View a meeting & its attachments | ✅ | ✅ | ✅ | ✅ | 🟡 |
| Submit a meeting response | ✅ | ✅ | ✅ | ✅ | 🟡 |
| Get meeting join link & ICS file | ✅ | ✅ | ✅ | ✅ | 🟡 |
| View a meeting registrant | ✅ | ✅ | | | |
| Manage meeting attachments | ✅ | | | | |
| Manage meeting registrants & occurrences | ✅ | | | | |
| Update & delete a meeting | ✅ | | | | |

#### Permission Inheritance

- ***Organizer***: inherited from Project Meeting Coordinator, Committee Writer, Project Writer
- ***Auditor***: inherited from Project Auditor

---

### Past Meeting

| | *Organizer* | *Auditor* | Host | Invitee | Attendee | *Everyone* |
|---|---|---|---|---|---|---|
| View a past meeting & its attachments | ✅ | ✅ | | ✅ | ✅ | 🟡 |
| View a past meeting summary | ✅ | | ✅ | ✅ | ✅ | |
| Update a past meeting summary | ✅ | | | | | |
| Manage past meeting participants & attachments | ✅ | | | | | |
| Update & delete a past meeting | ✅ | | | | | |

#### Permission Inheritance

- ***Organizer***: inherited from Project Meeting Coordinator, Project Writer, Scheduled Meeting Organizer
- ***Auditor***: inherited from Project Auditor, Scheduled Meeting Auditor

---

### Vote

| | *Writer* | *Auditor* | Participant | *Everyone* |
|---|---|---|---|---|
| View a vote & its status | ✅ | ✅ | ✅ | 🟡 |
| View aggregated voting results | ✅ | ✅ | | 🟡 |
| Cast a vote response | | | ✅ | |
| Extend, enable & resend a vote | ✅ | | | |
| Update & delete a vote | ✅ | | | |

#### Permission Inheritance

- ***Writer***: inherited from Project Writer, Committee Writer
- ***Auditor***: inherited from Project Auditor, Committee Auditor

---

### Vote Response

| | *Auditor* | Voter |
|---|---|---|
| View a vote response | ✅ | ✅ |
| Update your vote response | | ✅ |

#### Permission Inheritance

- ***Auditor***: inherited from Vote Auditor

---

### Survey

| | *Writer* | *Auditor* | Participant | *Everyone* |
|---|---|---|---|---|
| View a survey | ✅ | ✅ | ✅ | 🟡 |
| Preview survey send recipients | ✅ | ✅ | | |
| Manage survey recipients & responses | ✅ | | | |
| Update & delete a survey | ✅ | | | |

---

### Survey Response

| | Respondent |
|---|---|
