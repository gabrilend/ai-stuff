# Issue 609d: Offer a Shared List from the Game

**Phase:** 6
**Type:** Implementation
**Priority:** Low
**Dependencies:** 609c (the lobby prompt)

---

## Current Behavior

A receiver's game asks about a shared list and applies it (609c). But
nothing in the game lets a player offer theirs. `src/cli/share.lua make`
writes the list as a file, and `X:offer` sends one. Both are reachable
only from code, and the sharer's game must be running (and polling
rmail) to answer the receiver's request for files.

## Intended Behavior

- A player picks a contact and offers their list for the map they are on.
- While the offer is open, their game answers the request for files.

**After the editor-and-client split (2026-11-04).** As written, this
offers a list from a running game in this project's map viewer, which
gives way to Test Map (913). Under the owner's decisions a list travels
only with its map (609), in one of two ways, and neither is a game here:

- **"Check out my map"**: the map and the sender's list in one rmail
  message, sent from the editor (or the launcher). That part is this
  project's.
- **"Come check out my map"**: hosting a map, the host's list coming with
  the join. That is the W client's (its 1110).

So the steps below would be rewritten for the editor's "check out my map"
before this issue is built, and nothing here keeps a game polling rmail
to answer a request for files.

## Suggested Implementation Steps

1. A command (in the chat line, or a menu) that names a contact; the
   list is built from the player's packs for this map (`list.build`).
2. `Lb.exchange:offer(contact, l)`, with the pack as the exchange's
   `pack`.
3. A notice when the files were sent, and when the offer was refused.

## Acceptance Criteria

- [ ] A player offers a list from the game, and the other player's game
      asks about it
