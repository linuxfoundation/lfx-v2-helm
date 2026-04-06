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

| Job to Be Done                                      | Project Manager | Project Auditor (full read) | Project Meeting Coordinator |
|-----------------------------------------------------|-----------------|-----------------------------|-----------------------------|
| View project membership key contacts                |                 | ✅                           |                             |
| View project memberships & member companies         |                 | ✅                           |                             |
| View project membership tiers                       |                 | ✅                           |                             |
| View project settings                               |                 | ✅                           |                             |
| Create a vote                                       | ✅               | ✅                           |                             |
| Manage project membership key contacts              | ✅               | ✅                           |                             |
| Create project committees, meetings & mailing lists | ✅               | ✅                           |                             |
| Update project settings                             | ✅               | ✅                           |                             |
| Create & update a project                           | ✅               | ✅                           |                             |

#### Permission Inheritance

- **Project Manager**: inherited from parent Project
- **Project Auditor (full read)**: inherited from parent Project
- **Viewer (limited read)**: inherited from parent Project; all authenticated and anonymous users inherit Viewer (limited read) access when this Project is configured as public

---

### Committee

| Job to Be Done                                   | Committee Member | Committee Manager | Committee Auditor |
|--------------------------------------------------|------------------|-------------------|-------------------|
| View committee settings                          |                  |                   | ✅                 |
| Schedule a survey for a committee                |                  | ✅                 |                   |
| Manage committee links & folders                 |                  | ✅                 |                   |
| Manage committee members, invites & applications |                  | ✅                 |                   |
| Update & delete a committee                      |                  | ✅                 |                   |

#### Permission Inheritance

- **Committee Manager**: inherited from Project Manager
- **Committee Auditor**: inherited from Project Auditor (full read), Project Meeting Coordinator
- **Viewer**: inherited from Project Auditor (full read); all authenticated and anonymous users inherit Viewer access when this Committee is configured as public

---

### Groups.io Service

| Job to Be Done                      | Groups.io Service Owner | Groups.io Service Manager | Groups.io Service Auditor |
|-------------------------------------|-------------------------|---------------------------|---------------------------|
| Create project mailing lists        |                         | ✅                         | ✅                         |
| Update & delete a Groups.io service |                         | ✅                         | ✅                         |

#### Permission Inheritance

- **Groups.io Service Owner**: inherited from Project Owner
- **Groups.io Service Manager**: inherited from Project Manager
- **Groups.io Service Auditor**: inherited from Project Auditor (full read)
- **Viewer**: inherited from Project Auditor (full read); all authenticated and anonymous users inherit Viewer access when this Groups.io Service is configured as public

---

### Mailing List

| Job to Be Done                            | Mailing List Manager | Mailing List Auditor | Subscriber |
|-------------------------------------------|----------------------|----------------------|------------|
| Add, update & remove mailing list members | ✅                    |                      |            |
| Update & delete a mailing list            | ✅                    |                      |            |

#### Permission Inheritance

- **Mailing List Manager**: inherited from Groups.io Service Manager, Committee Manager
- **Mailing List Auditor**: inherited from Groups.io Service Auditor, Committee Auditor
- **Viewer**: inherited from Groups.io Service Viewer, Committee Member; all authenticated and anonymous users inherit Viewer access when this Mailing List is configured as public

---

### Scheduled Meeting

| Job to Be Done | Organizer | Host | Participant |
|---|---|---|---|

#### Permission Inheritance

- **Organizer**: inherited from Project Meeting Coordinator, Committee Manager, Project Manager

---

### Vote

| Job to Be Done       | Participant |
|----------------------|-------------|
| Cast a vote response | ✅           |

#### Permission Inheritance

- **Viewer**: all authenticated and anonymous users inherit Viewer access when this Vote is configured as public
- **Results Viewer**: all authenticated and anonymous users inherit Results Viewer access when this Vote is configured as public

---

### Vote Response

| Job to Be Done            | Voter |
|---------------------------|-------|
| Update your vote response | ✅     |

---

### Survey

| Job to Be Done | Participant |
|---|---|

#### Permission Inheritance

- **Viewer**: all authenticated and anonymous users inherit Viewer access when this Survey is configured as public
- **Results Viewer**: all authenticated and anonymous users inherit Results Viewer access when this Survey is configured as public

---

### Survey Response

| Job to Be Done | Respondent |
|---|---|
