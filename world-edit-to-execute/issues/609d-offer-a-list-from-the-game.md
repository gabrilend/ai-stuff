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

## Suggested Implementation Steps

1. A command (in the chat line, or a menu) that names a contact; the
   list is built from the player's packs for this map (`list.build`).
2. `Lb.exchange:offer(contact, l)`, with the pack as the exchange's
   `pack`.
3. A notice when the files were sent, and when the offer was refused.

## Acceptance Criteria

- [ ] A player offers a list from the game, and the other player's game
      asks about it
