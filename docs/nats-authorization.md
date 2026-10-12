<!-- Copyright The Linux Foundation and each contributor to LFX. -->
<!-- SPDX-License-Identifier: CC-BY-4.0 -->

# NATS publish authorization

Out of the box the platform NATS server has no authorization: any client
that can reach `lfx-platform-nats:4222` can publish on any subject. For most
subjects that is how the platform works today. A few subjects carry
assertions that a subscriber writes into durable state, and for those the
publisher's identity matters.

`nats.lfxAuthorization` in `charts/lfx-platform/values.yaml` restricts
publish on those subjects to named nkey identities. It does not require any
other service to change: clients that connect without credentials keep
working, they just lose publish on the restricted subjects.

It is **off by default**. Enabling a rule before its publisher connects with
its nkey stops that publisher's messages, so roll it out in the order below.

## How it works

`templates/nats/_authorization.tpl` renders a NATS `authorization` block,
which the nats subchart spreads into `nats.conf` through
`nats.config.merge.lfxAuthorization` (the nats chart's `$tplYamlSpread`).
With `enabled: false` it renders nothing and `nats.conf` is byte-identical to
a chart without this feature.

When enabled:

- Clients without credentials are mapped to `anonymousUser` through NATS
  `no_auth_user`. That user may subscribe to anything and publish to
  anything except the subjects of every enabled rule.
- Each entry under `users` with a non-empty `nkey` becomes an nkey user. It
  may publish to anything except the subjects of enabled rules that do not
  list it under `publishers`.
- A client presenting an nkey that is not listed is rejected outright, not
  downgraded to anonymous.

Only public nkeys (`U...`) go in values; the chart fails to render if a seed
is supplied. The seed stays in the publishing service's own Secret.

A user whose `nkey` is empty is not rendered. Its rules still apply, so
nobody can publish on them: the rule fails closed. Disable the rule instead
while its publisher has no nkey yet.

## Restricted subjects

| Rule | Subjects | Publisher |
|---|---|---|
| `inviteAccepted` | `lfx.invite.accepted` | `selfServe` |
| `inviteServiceAccepted` | `lfx.invite-service.invite_accepted` | `inviteService` |
| `invitesKV` | `$KV.invites.>` | `inviteService` |

- `lfx.invite.accepted`: the invite service writes the event's `username`
  into the invite record's `accepted_by`.
- `lfx.invite-service.invite_accepted`: the meeting service acts on it with a
  privileged ITX call.
- `$KV.invites.>`: a direct KV put would set `accepted_by` without going
  through either event.

Restricting only `lfx.invite-service.invite_accepted` is not enough: a
forged `lfx.invite.accepted` (or a direct KV write) poisons the stored invite
record that the meeting service re-reads to verify the event. Tracking issue:
linuxfoundation/lfx-self-serve-ops#493.

If the invite service's bucket is renamed from `invites`
(`INVITES_KV_BUCKET`), update `invitesKV.subjects` to match.

## Rollout

The order matters. A client that presents an nkey is refused by a server that
does not list it (`Authorization Violation`), and by a server with no
authorization at all (`nats: nkeys not supported by the server`, because the
server sends no nonce). So the server has to know the keys before any
service uses one.

1. Generate one user nkey per identity (`nk -gen user -pubout`, or
   `nsc generate nkey --user`). Each seed goes into that service's Secret,
   but is **not** wired into the service yet.
2. In `lfx-v2-argocd`, set the public keys and enable authorization with
   every rule off. Nothing is restricted yet; anonymous clients keep full
   rights, and the listed nkeys can now connect.

   ```yaml
   nats:
     lfxAuthorization:
       enabled: true
       users:
         inviteService:
           nkey: UA...   # public key only
         selfServe:
           nkey: UB...
       restrictedPublish:
         inviteAccepted:
           enabled: false
         inviteServiceAccepted:
           enabled: false
         invitesKV:
           enabled: false
   ```

3. Configure each publisher with its seed and confirm it reconnects as its
   nkey user.
4. Turn the rules on (drop the `enabled: false` overrides), one at a time if
   you prefer. Turn on a rule only once all of its `publishers` are on their
   nkeys.
5. Verify from `nats-box`, which connects without credentials:

   ```bash
   nats pub lfx.invite-service.invite_accepted '{}'
   # nats: Permissions Violation for Publish to "lfx.invite-service.invite_accepted"
   ```

Each config change rolls the NATS StatefulSet (the nats chart's config
checksum annotation), so plan it like any NATS restart.

## Not covered

- **Subscribe.** Any client can still subscribe to these subjects, including
  with the invite service's queue group, which would divert a share of
  deliveries away from it. That loses acceptances; it cannot forge one.
- **JetStream API on the bucket.** An anonymous client can still purge,
  delete or reconfigure the `KV_invites` stream through `$JS.API.>`. Denying
  that needs NACK, which creates the bucket, to run with its own identity.
- **Other subjects.** Every other subject is still open to every client.
  Add a rule here when a subscriber trusts the publisher's identity.
