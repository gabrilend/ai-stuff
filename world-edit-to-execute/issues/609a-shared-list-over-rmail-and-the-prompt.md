# Issue 609a: Shared Lists Over rmail, and the One Prompt

**Phase:** 6
**Type:** Implementation
**Priority:** Medium
**Dependencies:** 609 (shared map-and-model list)
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

**After the editor-and-client split (2026-11-04).** The owner settled
that playing happens in the W client (issue 913) and that using a shared
list during a game, the prompt included, is the W client's (its 1110);
this project sends, receives, checks and keeps lists (609, "Where each
part runs"). A list also travels only with its map: "check out my map"
sends the map and the list in one rmail message, and "come check out my
map" brings the host's list with the join, in the W client. So the rmail
items above stay here; the prompt "for this game" is the W client's,
and the one question this project asks is when a map is given to keep.

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

- [ ] A list sent over rmail arrives and is checked
- [ ] Only the missing files are attached in the reply
- [ ] A trusted sender's list applies without a prompt; others ask once
