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
- 🟡 access is conditional on per-object settings

## Object types

### Project

| | Writer | Auditor | Meeting Coordinator | *Everyone* |
|---|---|---|---|---|
| View a project | ✅ | ✅ | ✅ | 🟡 |
| View project meeting count | ✅ | ✅ | ✅ | 🟡 |
| View project settings | ✅ | ✅ | | |
| View project membership tiers | ✅ | ✅ | | |
| View project memberships & member companies | ✅ | ✅ | | |
| View project membership key contacts | ✅ | ✅ | | |
| Search B2B organizations | ✅ | ✅ | | |
| View B2B organization memberships | ✅ | ✅ | | |
| Manage project membership key contacts | ✅ | | | |
| Update project settings | ✅ | | | |
| Create & update a project | ✅ | | | |
| Create a vote | ✅ | | | |
| Create project committees & mailing lists | ✅ | | | |
| Create project meetings | ✅ | | ✅ | |
| Create past meetings | ✅ | | ✅ | |

#### Permission Inheritance

- **Writer**: inherited from parent Project
- **Auditor**: inherited from parent Project

---

### Committee

| | Writer | Auditor | Member | *Everyone* |
|---|---|---|---|---|
| View committee details | ✅ | ✅ | ✅ | 🟡 |
| View committee members | ✅ | ✅ | ✅ | 🟡 |
| View committee invites | ✅ | ✅ | ✅ | 🟡 |
| View committee applications | ✅ | ✅ | ✅ | 🟡 |
| View committee links | ✅ | ✅ | ✅ | 🟡 |
| View committee link folders | ✅ | ✅ | ✅ | 🟡 |
| Download committee documents | ✅ | ✅ | ✅ | 🟡 |
| View committee settings | ✅ | ✅ | | |
| Manage committee members, invites & applications | ✅ | | | |
| Manage committee links, folders & documents | ✅ | | | |
| Update committee settings | ✅ | | | |
| Update & delete a committee | ✅ | | | |
| Schedule a survey for a committee | ✅ | | | |

#### Permission Inheritance

- **Writer**: inherited from Project Writer
- **Auditor**: inherited from Project Auditor, Project Meeting Coordinator

---

### Groups.io Service

| | Writer | Auditor | *Everyone* |
|---|---|---|---|
| View a Groups.io service | ✅ | ✅ | 🟡 |
| Update & delete a Groups.io service | ✅ | | |
| Create project mailing lists | ✅ | | |

#### Permission Inheritance

- **Writer**: inherited from Project Writer
- **Auditor**: inherited from Project Auditor

---

### Mailing List

| | Writer | Auditor | Subscriber | *Everyone* |
|---|---|---|---|---|
| View a mailing list | ✅ | ✅ | ✅ | 🟡 |
| View & download mailing list artifacts | ✅ | ✅ | ✅ | 🟡 |
| View mailing list members | ✅ | ✅ | ✅ | 🟡 |
| Add & remove mailing list members | ✅ | | | |
| Update & delete a mailing list | ✅ | | | |

#### Permission Inheritance

- **Writer**: inherited from Groups.io Service Writer, Committee Writer
- **Auditor**: inherited from Groups.io Service Auditor, Committee Auditor

---

### Scheduled Meeting

| | *Organizer* | *Auditor* | Host | Participant | *Everyone* |
|---|---|---|---|---|---|
| View a meeting | ✅ | ✅ | ✅ | ✅ | 🟡 |
| Submit a meeting response | ✅ | ✅ | ✅ | ✅ | 🟡 |
| Get meeting join link & ICS file | ✅ | ✅ | ✅ | ✅ | 🟡 |
| View meeting registrants | ✅ | ✅ | ✅ | ✅ | 🟡 |
| View meeting RSVPs | ✅ | ✅ | ✅ | ✅ | 🟡 |
| View meeting attachments | ✅ | ✅ | ✅ | ✅ | 🟡 |
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
| View a past meeting | ✅ | ✅ | ✅ | ✅ | ✅ | 🟡 |
| View past meeting participants | ✅ | ✅ | ✅ | ✅ | ✅ | 🟡 |
| View past meeting recordings | ✅ | ✅ | ✅ | ✅ | ✅ | 🟡 |
| View past meeting transcripts | ✅ | ✅ | ✅ | ✅ | ✅ | 🟡 |
| View past meeting summaries | ✅ | ✅ | ✅ | ✅ | ✅ | 🟡 |
| View past meeting attachments | ✅ | ✅ | ✅ | ✅ | ✅ | 🟡 |
| View a past meeting summary | ✅ | ✅ | ✅ | 🟡 | 🟡 | 🟡 |
| Update a past meeting summary | ✅ | ✅ | ✅ | | | |
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
| View vote responses | ✅ | ✅ | ✅ | 🟡 |
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
| View survey responses | ✅ | ✅ | ✅ | 🟡 |
| Preview survey send recipients | ✅ | ✅ | | |
| Manage survey recipients & responses | ✅ | | | |
| Update & delete a survey | ✅ | | | |

#### Permission Inheritance

- ***Writer***: inherited from Project Writer, Committee Writer
- ***Auditor***: inherited from Project Auditor, Committee Auditor

---
