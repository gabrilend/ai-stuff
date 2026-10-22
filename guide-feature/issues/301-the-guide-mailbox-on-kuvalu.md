# 301 — The guide mailbox on kuvalu, port 1223

phase 3, the relay through rmail

## Current behavior

The owner said they would create an rmail inbox on kuvalu (192.168.1.100).
The vision gave port 111213, which cannot exist (ports stop at 65535), and
the owner then chose 1223 (`notes/first-answers.md`). Whether the mailbox
exists yet has not been checked.

## Intended behavior

An rmail mailbox named `guide` on kuvalu, separate from the owner's main
mailbox at `~/mail/`, listening on port 1223, with:

- a contact for each voice (`fg-sora-1`, `-2`, `-3`) with its `local-ip`
  (192.168.1.11–13), port (10101, 20202, 30303) and its own shared secret;
- `on_receive` and `on_update` both pointing at the arrival hook (302).

A setup script in `scripts/` builds a mailbox folder, its config and its
contacts from a short list of machines, generating each shared secret. The
same script builds the voices' mailboxes (702) and the stand-ins (305), so
every mailbox in the system is made one way. Secrets are written only into
each mailbox's `contacts` file, outside this repository.

## Suggested implementation steps

1. Check whether the owner already made the mailbox. If so, read its config
   and adopt it rather than overwrite it.
2. The setup script, using rmail's own mailbox-making scripts where they
   exist (`/home/ritz/programs/r-mail/scripts/`).
3. Check: the daemon starts and listens on 1223.

## Related documents

- `docs/rmail-constraints.md`
- `docs/network.md`

## Open questions

- Has the owner already made the mailbox, and where does it live?

## Blocked by

None.

## Blocks

302, 303, 305, 702.
