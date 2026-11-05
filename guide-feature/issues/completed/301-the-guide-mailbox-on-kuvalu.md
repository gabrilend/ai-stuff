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

## Decisions (2026-11-05; each the owner's to overturn)

1. **Whether the owner already made the mailbox can't be checked from
   here, so the script adopts it either way.** The guide mailbox lives at
   `~/guide-mail` on kuvalu, apart from `~/mail/`, set in `input/mailboxes`.
   If a mailbox is there already, its lines and secrets are kept, missing
   lines are added under a dated comment, and any line with another value
   (a different port, say) is refused, naming both values, before anything
   is written.
2. **The setup is this project's own script**, `scripts/make-mailboxes`
   (`src/031-mailboxes.lua`). rmail's `install.sh` asks questions and
   compiles rmail's dependencies, and `make-mailbox-drive.sh` is for USB
   drives; neither makes a set of linked mailboxes. It writes rmail's own
   file formats (rmail `README.md`, "Configuration").
3. **One list, `input/mailboxes`, makes all four mailboxes on kuvalu.** The
   voices' folders are copied to the mini-computers in 702, and the voices'
   `project` path (`/home/ritz/guide-feature`) is a placeholder until 702
   decides where guide-feature goes there. The rehearsal (305) uses the same
   script with its own set file.
4. **Links come from `contacts` lists**; either side naming the other makes
   one link. The voices know only the guide mailbox.
5. **Each pair's secret is 32 random bytes from `/dev/urandom`, as 64 hex
   digits**, the same on both sides, in `contacts` files only. They are
   never printed, `contacts` is 600 and the folder 700, and a mailbox folder
   inside this project is refused, so no secret can land in the repository.
6. **The hooks are a wrapper inside each mailbox**, `hooks/guide-hook`
   (rmail's own convention, its #102), running the project's
   `scripts/arrival-hook` (302) or `scripts/turn-hook` (304). The two calls
   are told apart by a word in the config line (`receive`, `update`), which
   rmail passes through because it runs the hook path unquoted.
7. **rmail's port mapping is turned off** in every config
   (`auto_port_forward = false`). Its public-address check has no switch in
   rmail, which `docs/network.md` asks for; that is rmail's to add.
8. **The voices are filed by `local-ip`**, which rmail tries first from the
   same home network. Mailboxes on one machine (the stand-ins) use `ip`.

## Implementation notes (2026-11-05)

- `src/031-mailboxes.lua` and `scripts/make-mailboxes`: the setup.
- `input/mailboxes`: the guide mailbox and the three voices.
- `src/032-test-mailboxes.lua`: 43 pass, in a throwaway folder.
- Mutation checks, 19, were each caught. Among them: an existing secret
  ignored, clashing secrets allowed, the two sides given different secrets,
  any port, a shared address or folder, a folder inside the project,
  `contacts` left readable, the folder left open, port mapping not turned
  off, a link counted twice, the hook's arguments split, a secret in the
  report.
- `docs/rmail-constraints.md` says how the mailboxes are made.
  `.file-index-counter` is at 032.

**Needs the owner's machine:**
- running `scripts/make-mailboxes` on kuvalu, where a guide mailbox may
  already exist;
- starting the guide mailbox's daemon (`run-rmail.sh ~/guide-mail/config`)
  and seeing it listen on 1223;
- a switch for rmail's public-address check (rmail's own change).
