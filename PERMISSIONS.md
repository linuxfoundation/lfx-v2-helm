<!-- Copyright The Linux Foundation and each contributor to LFX. -->
<!-- SPDX-License-Identifier: MIT -->
<!-- generated-intro
This file is generated automatically from
charts/lfx-platform/files/model.fga
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

| | *Owner* | Writer | Auditor | Meeting Coordinator | Executive Director | *Everyone* |
|---|---|---|---|---|---|---|
| View project details & meeting count | ✅ | ✅ | ✅ | ✅ | ✅ | 🟡 |
| View project links & folders | ✅ | ✅ | ✅ | ✅ | ✅ | 🟡 |
| View project documents | ✅ | ✅ | ✅ | ✅ | ✅ | 🟡 |
| View project settings | ✅ | ✅ | ✅ | | ✅ | |
| Create & update a project | ✅ | ✅ | | | | |
| Manage project links, folders & documents | ✅ | ✅ | | | | |
| Delete a project | ✅ | | | | | |
| Create project committees & Groups.io services | ✅ | ✅ | | | | |
| Create a vote poll | ✅ | ✅ | | | | |
| Create meetings & past meetings | ✅ | ✅ | | ✅ | | |

#### Permission Inheritance

- ***Owner***: inherited from parent Project, global Product Support Team, global Formation Team
- **Writer**: inherited from parent Project
- **Auditor**: inherited from parent Project, global LF Staff Team, global LF Contractor Team

---

### Committee

| | Writer | Auditor | Member | *Everyone* |
|---|---|---|---|---|
| View committee details & weekly brief | ✅ | ✅ | ✅ | 🟡 |
| View committee members, invites & applications | ✅ | ✅ | ✅ | 🟡 |
| View committee links, folders & documents | ✅ | ✅ | ✅ | 🟡 |
| View committee settings | ✅ | ✅ | | |
| Update & delete a committee | ✅ | | | |
| Manage committee members, invites & applications | ✅ | | | |
| Manage committee links, folders & documents | ✅ | | | |
| Generate & edit the committee weekly brief | ✅ | | | |
| Create a committee survey | ✅ | | | |

#### Permission Inheritance

- **Writer**: inherited from Project Writer
- **Auditor**: inherited from Project Auditor, Project Meeting Coordinator

---

### Committee Invite

| | *Viewer* | Invitee |
|---|---|---|
| View a committee invite | ✅ | ✅ |

#### Permission Inheritance

- ***Viewer***: inherited from Committee Auditor

---

### Groups.io Service

| | Writer | Auditor | *Everyone* |
|---|---|---|---|
| View a Groups.io service | ✅ | ✅ | 🟡 |
| View Groups.io service settings | ✅ | ✅ | |
| Update & delete a Groups.io service | ✅ | | |
| Create a Groups.io mailing list | ✅ | | |

#### Permission Inheritance

- **Writer**: inherited from Project Writer
- **Auditor**: inherited from Project Auditor

---

### Mailing List

| | Writer | Auditor | Subscriber | *Everyone* |
|---|---|---|---|---|
| View a Groups.io mailing list & members | ✅ | ✅ | ✅ | 🟡 |
| View & download Groups.io artifacts | ✅ | ✅ | ✅ | 🟡 |
| View Groups.io mailing list settings | ✅ | ✅ | | |
| Manage Groups.io mailing list members | ✅ | | | |
| Update & delete a Groups.io mailing list | ✅ | | | |

#### Permission Inheritance

- **Writer**: inherited from Groups.io Service Writer, Committee Writer
- **Auditor**: inherited from Groups.io Service Auditor, Committee Auditor

---

### Scheduled Meeting

| | *Organizer* | *Auditor* | Host | Participant | *Everyone* |
|---|---|---|---|---|---|
| View a meeting & join link | ✅ | ✅ | ✅ | ✅ | 🟡 |
| Submit a meeting RSVP & download attachments | ✅ | ✅ | ✅ | ✅ | 🟡 |
| View meeting registrants & RSVPs | ✅ | ✅ | ✅ | ✅ | 🟡 |
| View a meeting registrant | ✅ | ✅ | | | |
| Manage meeting registrants & invitations | ✅ | | | | |
| Manage meeting attachments | ✅ | | | | |
| Update & delete meetings & occurrences | ✅ | | | | |

#### Permission Inheritance

- ***Organizer***: inherited from Project Meeting Coordinator, Committee Writer, Project Writer
- ***Auditor***: inherited from Project Auditor

---

### Past Meeting

| | *Organizer* | *Auditor* | Host | Invitee | Attendee | *Everyone* |
|---|---|---|---|---|---|---|
| View a past meeting & attachments | ✅ | ✅ | ✅ | ✅ | ✅ | 🟡 |
| View past meeting participants | ✅ | ✅ | ✅ | ✅ | ✅ | 🟡 |
| View past meeting recordings | ✅ | ✅ | 🟡 | 🟡 | 🟡 | 🟡 |
| View past meeting transcripts | ✅ | ✅ | 🟡 | 🟡 | 🟡 | 🟡 |
| View past meeting AI summaries | ✅ | ✅ | 🟡 | 🟡 | 🟡 | 🟡 |
| Manage past meeting participants & attachments | ✅ | | | | | |
| Update & delete past meetings & summaries | ✅ | | | | | |

#### Permission Inheritance

- ***Organizer***: inherited from Project Meeting Coordinator, Project Writer, Scheduled Meeting Organizer
- ***Auditor***: inherited from Project Auditor, Scheduled Meeting Auditor

---

### Vote

| | *Writer* | *Auditor* | Participant | *Everyone* |
|---|---|---|---|---|
| View vote polls & vote responses | ✅ | ✅ | ✅ | 🟡 |
| View vote results | ✅ | ✅ | 🟡 | 🟡 |
| Cast a vote response | | | ✅ | |
| Extend a vote & resend notifications | ✅ | | | |
| Update, enable & delete a vote | ✅ | | | |

#### Permission Inheritance

- ***Writer***: inherited from Project Writer, Committee Writer
- ***Auditor***: inherited from Project Auditor, Committee Auditor

---

### Vote Response

| | *Auditor* | Voter |
|---|---|---|
| View a vote response | ✅ | ✅ |
| Submit & update a vote response | | ✅ |

#### Permission Inheritance

- ***Auditor***: inherited from Vote Auditor

---

### Survey

| | *Writer* | *Auditor* | Participant | *Everyone* |
|---|---|---|---|---|
| View survey details & responses | ✅ | ✅ | ✅ | 🟡 |
| Preview survey resend impact | ✅ | ✅ | | |
| Resend survey emails & manage recipients | ✅ | | | |
| Update & delete a survey | ✅ | | | |

#### Permission Inheritance

- ***Writer***: inherited from Project Writer, Committee Writer
- ***Auditor***: inherited from Project Auditor, Committee Auditor

---

### B2B Organization

| | Owner | Writer | Auditor |
|---|---|---|---|
| View org details, settings & committee seats | ✅ | ✅ | ✅ |
| View org workspaces & workspace projects | ✅ | ✅ | ✅ |
| Update org details & access settings | ✅ | ✅ | |
| Manage membership committee seat assignments | ✅ | ✅ | |

#### Permission Inheritance

- **Auditor**: inherited from parent B2B Organization, child B2B Organization, Project Membership Key Contact

---

### Project Membership

| | *Writer* | *Auditor* | Key Contact |
|---|---|---|---|
| View project membership & key contacts | ✅ | ✅ | |
| Create, update & delete key contacts | ✅ | | |

#### Permission Inheritance

- ***Writer***: inherited from B2B Organization Writer
- ***Auditor***: inherited from B2B Organization Auditor, Project Auditor
