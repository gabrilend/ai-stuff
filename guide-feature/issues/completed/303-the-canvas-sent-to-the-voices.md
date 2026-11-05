# 303 — The canvas sent to the voices

phase 3, the relay through rmail

## Current behavior

Versions reach files on kuvalu (203). The voices cannot see them.

## Intended behavior

A publisher in the blitter's list writes each new version as the body of
`outbox/the-canvas` in the guide mailbox, with the to-voices headers
(`docs/canvas-format.md`: `canvas`, `size`, `mode`, `project`, `written`),
under one `to:` line per voice, by temporary name and rename. kuvalu is the
author, so every edit travels, and each voice's `inbox/the-canvas` always
holds the newest version. A voice that was offline gets only the newest one
when it is reached.

When the tell-the-voice setting is on, the body ends with a `cuts:` section
(`docs/canvas-format.md`, "Cuts"), listing the words each voice cut since its
previous turn landed, taken from the blit's change report (106). All three
voices get the same body, and each reads its own lines.

The `project:` header comes from `input/blitter`: the project being worked
on and its current commit, read from that project's git checkout on kuvalu
at each version. Changing the project is changing one setting.

## Suggested implementation steps

1. The publisher, using the canvas writer (102).
2. Test with the stand-ins (305): each receives the canvas, and receives
   edits as it changes.
3. Count versions handed to rmail in the goodbye receipt.

## Related documents

- `docs/datapath-round-trip.md`, step 1
- `docs/rmail-constraints.md`, "A living message"

## Blocked by

106, 203, 301.

## Blocks

305.

## Decisions (2026-11-05; each the owner's to overturn)

1. **The publisher's settings are their own file, `input/to-voices`**
   (send, mailbox, tell-the-voice, endpoint, project-checkout), read when
   the blitter starts. `tell-the-voice` moved there from the planned
   `input/blitter`, since it only shapes what is mailed. The blitter mails
   only when run as a program (`scripts/run-blitter`); the demos and tests
   that run it so write `send = "off"` (`series.TO_VOICES_OFF`).
2. **It refuses to start rather than send versions nowhere**: no mailbox at
   the folder, a voice in `input/blitter` that is not one of its contacts,
   an endpoint that is not a name and an address, or a project folder that
   is not a git checkout.
3. **The `endpoint` header is one setting for every voice until 402.** The
   to-voices form requires it, and one body goes to all three, so per-voice
   endpoints (`use.fg-sora-1` and so on in `endpoints`) cannot each have a
   header yet. The value is a placeholder, `voice-small
   http://192.168.1.100:20166`, until 401a picks ports and 402 reads it
   from `endpoints`.
4. **The project's commit is read from `project-checkout` at every
   version**, as the issue asks. The viewers' header still carries the
   commit the blitter read at start from its own root; making the two read
   the same checkout is a small change left for 501, where the voices'
   clones need it.
5. **A voice's cut lines are those of its latest turn that made a
   version.** They stay in every body until its next such turn replaces
   them (with its own cuts, or none). A turn that changed nothing makes no
   version, so it does not clear them.
6. **The outbox file is rewritten whole each version, `to:` lines and
   all.** A voice that deleted its inbox copy is therefore sent the canvas
   again as a new message. rmail rewrites the outbox file only to remove a
   `to:` line, which this design never expects; if the two writes ever
   met, the next version would put the line back.
7. **Marks travel to the voices too**, written as kuvalu writes them for
   viewers, since the format says the rows and marks are written the same
   way everywhere.

## Implementation notes (2026-11-05)

- `src/035-to-voices.lua`: the publisher. `src/016-blitter.lua` passes the
  voice to every publisher and, run as a program, adds this one.
- `input/to-voices`: on, `~/guide-mail`, tell-the-voice on, the placeholder
  endpoint, this project's checkout.
- `src/036-test-to-voices.lua`: 21 pass. `src/017`, the phase 1 and 2
  demos write `send = "off"` for their throwaway projects.
- Mutation checks, 16, were each caught but one: the part file written
  without its leading dot, which a test that runs one thing at a time
  cannot see (rmail skips dot files, so the dot is kept).
- `docs/datapath-round-trip.md` step 1, `docs/datapath-blit.md`.
  `.file-index-counter` is at 036.

**Needs the owner's machine:** the live guide mailbox's daemon carrying
`the-canvas` to the voices' inboxes, each receiving every edit. The
rehearsal (305) does this with stand-in mailboxes.
