# 301 — The guide mailbox on kuvalu, port 1223

phase 3, the relay through rmail

## Current behavior

The owner said they would create an rmail inbox on kuvalu (192.168.1.100).
The vision gave port 111213, which cannot exist (ports stop at 65535). The
owner then chose 1223 (`notes/first-answers.md`). Whether the mailbox exists
yet has not been checked.

## Intended behavior

An rmail mailbox named `guide` on kuvalu, separate from the owner's main
mailbox at `~/mail/`, listening on port 1223, with:

- a contact entry for each voice (`fg-sora-1`, `-2`, `-3`) with its
  `local-ip` (192.168.1.11–13) and port (10101, 20202, 30303) and its own
  shared secret;
- `on_receive` and `on_update` pointing at the arrival hook (302).

A setup script in `scripts/` builds the mailbox folder, its config and its
contacts from a small settings file, generating each shared secret, so the
mailbox can be rebuilt rather than hand-edited. The secrets are written only
into the mailbox's `contacts` file, which lives outside this repository, and
printed once for copying to the fg-sora side (502).

## Suggested implementation steps

1. Check whether the owner already created the mailbox. If so, read its
   config and adopt it rather than overwrite it.
2. The setup script, using rmail's own install and mailbox-making scripts
   where they exist (`/home/ritz/programs/r-mail/scripts/`).
3. Open port 1223 in kuvalu's firewall for the local network only.
4. Check: the daemon starts, and `ss -ltn` shows it listening on 1223.

## Related documents

- `docs/rmail-constraints.md`
- `docs/architecture.md`, "The machines"

## Open questions

- Has the owner already made the mailbox, and where does it live?

## Blocked by

None.

## Blocks

302, 303, 304, 502.
