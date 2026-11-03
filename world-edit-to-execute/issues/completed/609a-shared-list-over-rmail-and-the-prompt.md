# Issue 609a: Shared Lists Over rmail, and the One Prompt

**Phase:** 6
**Type:** Implementation
**Priority:** Medium
**Dependencies:** 609 (shared map-and-model list)
**Blocks:** 609b
**Uses:** rmail (`/home/ritz/programs/r-mail/`), not in this repository

---

## Current Behavior

609 builds the list, the receiver's check and the one-game profile, as
four file steps (`src/cli/share.lua`: make, missing, bundle, check), and
remembers "always from this player" and "always for this map". Nothing
carries the files between players, and there is no prompt in the game.

## Intended Behavior

- The outgoing list is written as an rmail message into `~/mail/outbox/`.
- An `on_receive` hook recognises a list, replies with the missing
  hashes, and (for a trusted player or map: `profile.trust`) answers
  rmail's consent request the way the person would.
- The sharer's hook answers a request for hashes with the bundle as
  attachments.
- The game shows the one prompt ("Use Ana's models for this game?") with
  the provenance of each entry, applies the profile when accepted, and
  reverts it after the game unless the player keeps it.

## Suggested Implementation Steps

1. Read rmail's message, attachment and hook formats.
2. An outbox writer for `share.lua make`'s list, and a hook that answers
   with `missing`.
3. The sharer's hook: `bundle` as attachments.
4. The prompt in the lobby, with each entry's provenance; `profile.apply`
   and `attach` on yes, `revert` after the game.

## Open Questions

1. Can an rmail hook answer the consent request for the person (609's
   "to confirm while building")? This needs rmail's own docs
   (`docs/attachments.md`, `docs/.templates/scripting-tutorial.md`).

## Acceptance Criteria

- [x] A list sent over rmail arrives and is checked (through a fake rmail
      built to the assumed contract; the real glue is 609b)
- [x] Only the missing files are attached in the reply
- [x] A trusted sender's list applies without a prompt; others ask once

## Implementation Notes (2026-11-03)

Built behind an interface, as decided for Ritz on 2026-11-03: rmail is in
a separate repository that isn't attached here, so it was not fetched.
The world-edit side is complete and tested; what is left is the glue to
the real rmail and the prompt on screen (609b).

- `src/share/exchange.lua`: the conversation (offer, want, files) over any
  transport with `send(to, message)`, and the consent step, which
  defaults to asking.
- `src/share/rmail_hook.lua`: a transport and an `on_receive` hook for
  rmail, written to the assumed contract below. `hook.connect()` is the
  stub: it says rmail isn't attached.
- `src/tests/test_share_exchange.lua`: 32 tests. Ana and Ben trade
  through a fake rmail. The tests cover asking, yes, no, trust, a game
  that answers at once, and everything each side refuses.
- Docs: `src/share/exchange.info.md` and `src/share/rmail_hook.info.md`.

### The rmail hook contract (an assumption, not yet checked against rmail)

When rmail is read, check these; only `rmail_hook.lua` should change.

1. **rmail calls `on_receive(message, rmail)`** for every message that
   arrives. The message is `{ from, subject, body, attachments = { { name,
   path } } }`, and the attachments are already saved as files.
2. **`from` is a sender rmail has authenticated.** The sharer sends files
   only to the player it offered them to, and the receiver takes files only
   from the player it asked. Both trust `from`.
3. **The hook can send** with `rmail.send({ to, subject, body,
   attachments = { { name, path } } })`, where attachments are read from
   those paths.
4. **Consent:** `on_receive` returns `"accept"`, `"decline"`, `"ask"` (rmail
   asks the person as it would without the hook), or nil (not ours: rmail
   goes on as usual). The hook only says `"accept"` to share mail the game
   took. A list carries no files, and files are taken only when the player
   (or their trust setting) already said yes, so rmail's consent is
   answered by the game's own prompt rather than a second one.
5. **Subjects are free text** up to at least 80 characters, and bodies hold
   a list file (up to 4 MiB).

### Decisions made while building

1. **Consent before any download.** The player is asked when the list
   arrives. Files are requested only after yes, so a declined list costs
   nothing and leaves nothing on disk.
2. **The default consent is "ask later".** A question waits in
   `X:pending()` until the game shows the prompt and calls `X:answer`. A
   game can instead pass a `consent` function that answers at once.
3. **A sharer serves only what it offered, to the player it offered it
   to.** A want names the offer's id. Any hash outside that list, or a
   request from another sender, is refused. Without this rule a want
   could fetch any file in the sharer's store.
4. **A receiver takes only files it asked that sender for**, and only
   under a hash's hex name. An attachment named like a path is ignored, and
   every file is then checked against its hash by `profile.apply`.
5. **Messages are plain tables, and the mail format is the hook's
   business.** The exchange can then run over another carrier (a folder,
   a game server) without changes.
6. **Questions are kept in memory, not on disk.** A list that arrives
   while the game is closed is still in rmail, and rmail delivers it again.
7. **The prompt's words come from `exchange.prompt(q)`**, which gives the
   question, the map, and for each entry its file, size and where else it
   can be had. Drawing it in the lobby needs a screen, so it is 609b.
8. **The open question (can a hook answer consent?) is answered as an
   assumption** (contract item 4), to be checked against rmail's docs in
   609b.

