# Issue 609b: rmail Glue and the Lobby Prompt

**Phase:** 6
**Type:** Implementation
**Priority:** Medium
**Dependencies:** 609a (the exchange and the assumed hook)
**Uses:** rmail (`/home/ritz/programs/r-mail/`), not in this repository

---

## Current Behavior

`src/share/exchange.lua` carries a shared list between two players over
any transport, and asks the player first. `src/share/rmail_hook.lua`
connects it to rmail, but it was written against an *assumed* hook
contract (see 609a's notes), because rmail isn't attached to this
repository, and `hook.connect()` is a stub. The prompt's words exist
(`exchange.prompt`), but nothing shows them in the game.

## Intended Behavior

- Lists, wants and files travel over the real rmail.
- The lobby shows the one prompt with each entry's provenance. It applies
  the profile on yes (`P:attach(L)`), and reverts it after the game unless
  the player keeps it (`P:keep`).

## Suggested Implementation Steps

1. Read rmail's message, attachment and hook docs (`docs/attachments.md`,
   `docs/.templates/scripting-tutorial.md`). Check the five assumptions
   in 609a's contract, and change only `rmail_hook.lua` where they differ.
2. Replace the `hook.connect()` stub: find rmail, and register
   `on_receive`.
3. The lobby prompt: show `exchange.prompt(q)` for each of `X:pending()`,
   with Yes, No, "Always from this player" and "Always for this map".
4. After the game: `P:revert(L)`, or `P:keep(name, L)` when the player
   asks to keep it.

## Acceptance Criteria

- [ ] A list sent over the real rmail arrives and is checked
- [ ] The prompt shows in the lobby and its answer is used
- [ ] An applied list is gone after the game unless kept
