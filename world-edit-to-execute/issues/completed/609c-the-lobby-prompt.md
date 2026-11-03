# Issue 609c: The Lobby Prompt for a Shared List

**Phase:** 6
**Type:** Implementation
**Priority:** Medium
**Dependencies:** 609b (rmail glue)
**Blocks:** 609d (offering a list from the game)

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

## Suggested Implementation Steps

1. Connect and poll from the game's loop; show the setup lines when
   `C:hooked()` is false.
2. The lobby prompt: show `exchange.prompt(q)` for each of `X:pending()`,
   with Yes, No, "Always from this player" and "Always for this map".
3. After the game: `P:revert(L)`, or `P:keep(name, L)` when the player
   asks to keep it.

## Acceptance Criteria

- [x] The prompt shows in the lobby and its answer is used (layout and
      clicks tested with a stand-in renderer; not yet looked at on screen)
- [x] An applied list is gone after the game unless kept
- [ ] A list sent over a live rmail arrives and is checked (no live rmail
      here; the file-level fake in `test_share_rmail.lua` stands in)

## Implementation Notes (2026-11-03)

- `src/share/lobby.lua`: the game's side, without drawing.
  - It polls rmail every 5 seconds, the first time at once.
  - It shows one dialog at a time (question, ready, notice) and takes the
    player's answer.
  - It puts an applied list on the loader, and takes it off at the end
    of the game.
  - It settles what an earlier game left behind.
- `src/ui/wc3/share_prompt.lua`: draws those dialogs over the HUD, in the
  map dialogs' style, and takes the mouse while one shows.
- `src/ui/wc3/hud.lua`: `hud.share` is drawn after the map's dialogs, and
  updated before them.
- `src/demo/wc3map/main.lua`: `WETE_RMAIL=<rmail config>` turns this on.
  - The game opens a loader for this game.
  - It polls from the game's tick.
  - End Game reverts what was applied.
  - The scripted action `share:N` presses a button of the prompt.
- `src/share/profile.lua`: `profile.leftovers` and `profile.open`, which
  read back a profile left applied.
- `src/tests/test_share_lobby.lua`: 39 tests.

### Decisions (the open questions, answered)

1. **There is no lobby screen, so the prompt is a dialog over the game.**
   The map starts at once. The prompt is drawn like the map's own dialogs,
   and comes before them.
2. **A list applied mid-game reaches what the loader serves at once, but
   not yet the screen.**
   - The scene still draws its art through `assets.open`, not the loader.
   - 606a's step 2 moves `assets/gpu.lua` and `assets/ground.lua` onto the
     loader.
   - Until then an applied list changes what the loader serves (and
     `P.types`), not the models on screen.
   - This was not worked around here.
3. **One dialog at a time, in a fixed order.**
   - Questions come first, oldest first.
   - Then "<sender>'s models are in use", once for each list applied.
   - Then notices: refusals, a failed poll, rmail without the hooks, what
     was kept from the last game.
4. **"Always from" and "Always for this map" also answer yes.** They
   apply this list and the next ones without asking.
5. **No key answers a question.** Only a click does, so a stray Enter or
   Esc never says yes or no. On a "ready" dialog or a notice, Enter
   presses the first button and Esc presses OK.
6. **"After the game" is End Game, or the next start.**
   - The viewer has no hook for a closed window or a stopped program.
   - So End Game reverts what was applied, and the next start settles
     whatever a game left behind.
   - A list the player chose to keep is written down at once
     (`profiles/<name>.keep`), so it is kept either way.
   - Two games running on one data folder at the same time would settle
     each other's lists. That is not guarded against.
7. **Keep is offered once the list is in use, not after the game.** No
   post-game screen exists. A kept list is named "<sender>'s models for
   <map>", with a number added when that name is taken.
8. **Shared lists are opt-in and never stop a game.**
   - They are on only when `WETE_RMAIL` names an rmail config.
   - Anything that fails while setting up turns them off and prints why.
   - A failed poll becomes a notice.
9. **The provenance lines are capped**, at 14 entries plus "and N more".
   On a small screen, lines are cut further and counted.
10. **Not looked at on screen.** No window could be opened here. The
    layout and clicks are tested with a stand-in for the renderer.

### Simpler once r-mail#1 merges (gabrilend/r-mail#1)

r-mail#1 adds an `on_consent` hook and a fourth `on_package` argument.
Nothing in `lobby.lua` or `share_prompt.lua` changes; the glue under them
(`rmail_hook.lua`, 609b) gets simpler:

- **Consent:** `C:poll` scans the inbox for consent forms and answers
  them. An `on_consent` script could answer each form as it arrives,
  even while the game is closed, from a list of wanted files the exchange
  writes when it asks.
- **Files:** a file is matched to its message by sender and name. With
  `on_package`'s `$4`, each file names its message.
- **Setup:** the setup notice would then list three hook lines, not two.
