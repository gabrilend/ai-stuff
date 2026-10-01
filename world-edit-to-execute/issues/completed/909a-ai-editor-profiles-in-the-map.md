# Issue 909a: AI Editor — The Computer Players' Profiles, Edited and Saved into the Map

**Phase:** 9 (editor)
**Type:** Implementation
**Priority:** High
**Parent:** 909 (AI editor)
**Dependencies:** 901 (editor core), 521 (AI profiles), 540 (computer players act)

---

## Current Behavior

- **Profiles:** computer players play AI Editor profiles (`ai/profile.lua`). A profile is either:
  - a file in `ai-profiles/<map>/pNN-*.lua` (DAoW 5.4b has eleven), or
  - derived from what the faction owns (`ai/faction.lua`).
- **Editing:** only by editing those files by hand.
- **Edited maps:** a copy saved under another name finds no profiles folder, so the game derives its AI again.

## Intended Behavior

### Opening

- The editor's "AI" button opens the AI editor over the view.
- Each computer player that owns something when the map starts has a profile. It comes from the first of these that exists:
  1. its file in the profiles folder;
  2. the one the map carries;
  3. one derived from what it owns.
- To see who owns what, the map's script runs once, as the game would.

### The tabs

- **General:**
  - name and race;
  - the fourteen options (checkboxes);
  - workers on gold and lumber;
  - the target priorities, each with a condition.
- **Heroes:** the heroes and their skill orders.
- **Build:** unit, hero, upgrade and expansion lines. Each has an id (typed, or picked from what the player's buildings train), a count and a condition.
- **Groups:** the attack groups and their units.
- **Waves:** first delay, delay between waves, repeat point, longest wait, and how much of the group must gather; the waves, each with a group and a condition.
- **Conditions:** the named conditions.

### Editing

- Conditions are typed as Lua tables and read as data only.
- Every change is one step to undo.
- Checking reports problems such as waves naming groups that don't exist.

### Saving and playing

- Saving writes each changed profile into the map as `war3mapAI\pNN.lua`, with unit names as comments.
- When the profiles folder has no file for a player, the game gives that player the map's profile:
  - it reads the file as data only;
  - an edited map carries its AI with it.
- "Export" writes the changed profiles to the profiles folder instead: the owner's own copies, which come first.

## Suggested Implementation Steps

1. `ai/faction.lua`: `map_file`, `read_profile` (sandboxed), and `load_or_derive` reading the map's profile; `ai/init.lua` passes the map reader.
2. `editor/ai.lua`: `load_ai`, and undoable `ai_set`, `ai_insert`, `ai_remove` and `ai_move` by path; `ai_check`, `ai_files` (saving) and `export_ai`.
3. `editor/ai_ui.lua`: the panel. `editor/ui.lua`: the AI button.
4. Tests.

## Acceptance Criteria

- [x] DAoW 5.4b's eleven computer players' profiles opened from the profiles folder
- [x] Build priorities, groups, waves, options, workers and conditions edited; moved; removed; undone
- [x] Checking finds a wave naming a group that doesn't exist
- [x] Saved into the map; the game plays the map's profile when the folder has none:
  - [x] with the edited name, options and workers
  - [x] its first wave goes at the edited time and sends the edited group
  - [x] no script errors
- [x] Opened again: the map's profile read back
- [x] A profile carried in a map can't run code
- [x] Exported to a folder
- [x] The panel driven headless in the tests (picking types, typing conditions, stepping numbers, Ctrl+Z), and seen in the window (screenshots, not committed)

## Notes

- **Tests:** `src/tests/test_ai_editor.lua` (46 tests).
- **Not WC3's files:** WC3's AI Editor makes `.wai` and `.ai` files. These profiles are this engine's own, and WC3 itself won't play them. A map's own `.ai` JASS scripts still run as before (issue 521).
- **Precedence:** the profiles folder comes before the map's profile, so an owner's local edits win. Editing a folder profile and saving the map under the same name therefore changes nothing until the folder file is exported or removed.
