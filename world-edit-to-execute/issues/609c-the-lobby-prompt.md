# Issue 609c: The Lobby Prompt for a Shared List

**Phase:** 6
**Type:** Implementation
**Priority:** Medium
**Dependencies:** 609b (rmail glue)

---

## Current Behavior

A shared list arrives over rmail (609b) and waits in `X:pending()` for
the player's answer. The prompt's words exist (`exchange.prompt(q)`), but
nothing shows them in the game, and nothing calls `C:poll(X)` from the
game's loop.

## Intended Behavior

- The game connects to the player's rmail (`hook.connect`), polls it
  every few seconds, and says when the hooks aren't set up yet
  (`C:hooked()`, with `C:install()`'s lines to add).
- The lobby shows the one prompt with each entry's provenance. It applies
  the profile on yes (`P:attach(L)`), and reverts it after the game unless
  the player keeps it (`P:keep`).

**After the editor-and-client split (2026-11-04).** Two items above are
no longer this project's as written. The lobby prompt, for "come check
out my map" where the host's list comes with the join, is the W client's
(its 1110): playing happens there (issue 913), and it carries this
issue's rules over as a design (609, "A list travels only with its
map"). And no inbox is polled on a timer: the owner, "we don't need to
check the rmail inbox every 5 seconds", since models travel only when
their map is shared. What stays here is the one question the editor or
launcher asks when a map is given to keep ("check out my map").

Since then (609, "After the editor-and-client split") the one-game parts
named above and in the steps below, `profile.apply`, `P:attach`,
`P:revert` and `P:keep`, and the loader's `push_layer` / `pop_layer`,
were taken out of this project: a checked list is kept as one of the
player's packs (`profile.keep`, through the exchange's `X:keep`), and
the steps below are kept as the design the W client's 1110 builds from.

## Suggested Implementation Steps

1. Connect and poll from the game's loop; show the setup lines when
   `C:hooked()` is false.
2. The lobby prompt: show `exchange.prompt(q)` for each of `X:pending()`,
   with Yes, No, "Always from this player" and "Always for this map".
3. After the game: `P:revert(L)`, or `P:keep(name, L)` when the player
   asks to keep it.

## Acceptance Criteria

- [ ] The prompt shows in the lobby and its answer is used
- [ ] An applied list is gone after the game unless kept
- [ ] A list sent over a live rmail arrives and is checked
