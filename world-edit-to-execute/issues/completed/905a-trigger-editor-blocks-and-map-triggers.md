# Issue 905a: Trigger Editor — Blocks Written as JASS, and the Map's Own Triggers

**Phase:** 9 (editor)
**Type:** Implementation
**Priority:** Critical
**Parent:** 905 (trigger editor)
**Dependencies:** 901 (editor core), 911a (writing maps back), 520 (JASS VM)

---

## Current Behavior

The editor edits terrain, objects, object types and regions, but no triggers. None of the 16 maps in `assets/` has a `war3map.wtg` or `war3map.wct`: their triggers exist only as the JASS in `war3map.j`. DAoW's script is protected: its names are shortened, and many of its lines end in a bare carriage return.

## Intended Behavior

### The editor's own triggers

- **Blocks:** triggers are built from blocks, as in the World Editor's trigger GUI:
  - events;
  - conditions;
  - actions, where if / then / else, for loops and "pick every unit in region" hold more actions.
- **Variables:** a trigger can use variables (integer, real, boolean, string, unit, group, player, location, timer; arrays too).
- **JASS in the script:** saving writes the triggers into the map's script as JASS, so the saved map still plays in WC3.
  - Variable and trigger globals are written before `endglobals`.
  - The functions are written before `main`.
  - A call to `EditorInitTriggers()` is written at the end of `main`. It makes the triggers and runs the map-initialization ones.
  - Each piece stands between `//EDITOR-BEGIN` and `//EDITOR-END` lines, which opening the map takes out again.
- **Stored in the map:** the blocks are kept in the map as `war3mapEditor.lua`, a table of data read back without running any code.
- **Code view:** shows the JASS one trigger becomes, read only, in colour.
- **Checking:** reports:
  - missing regions, triggers and variables;
  - triggers with no events;
  - names that clash;
  - JASS that doesn't parse;
  - optionally, whether the whole saved script loads.
- **Undo:** every change is one step to undo.

### The map's own triggers

- **Listed:** from the script, each `set X = CreateTrigger()` with the `TriggerRegister*`, `TriggerAddCondition` and `TriggerAddAction` calls after it. DAoW 5.4b has 312; Daow4.4 has 637.
- **Code editing:** any function of the script can be opened in the code view and rewritten. Apply keeps the edit; it is written back on save.
- **Switched off:** a trigger's `TriggerAddAction` calls become `DoNothing()`.

### The panel

- **Opening:** "Triggers" on the toolbar opens the panel over the view.
- **Lists on the left:** the editor's triggers, the variables, and the map's triggers (paged).
- **Block tree:** each line can be moved up, moved down or removed. Adding a block opens a chooser listing the block kinds.
- **Parameter editor:** for the chosen block:
  - numbers and players step with - / +;
  - unit roles, regions, triggers, variables, comparisons and booleans cycle through their choices;
  - any value can be typed; typed text that isn't a literal becomes a JASS expression.
- **Code view keys:** typing, arrows, Home/End, Page Up/Down and the wheel.
  - Keys repeat while held.
  - The camera holds still while the panel is open.

## Suggested Implementation Steps

1. `editor/trigger_blocks.lua`: the block catalog, how values become JASS, and the one-line descriptions.
2. `editor/triggers.lua`: the model and its undoable edits; JASS generation; insertion with markers and stripping them again; `war3mapEditor.lua`; checking; the scan of the map's own triggers; function rewrites; switching triggers off.
3. `editor/save.lua`: gather the map-trigger edits (a rewritten function's text wins over other edits inside it), insert the trigger code, and write `war3mapEditor.lua`.
4. `editor/textedit.lua`: the code view.
5. `editor/trigger_ui.lua`: the panel. `editor/ui.lua`: the Triggers button and routing input to the panel.
6. `scene_viewer.c`: the editing keys, key repeat, `viewer.wheel()` and `viewer.hold_camera()`.
7. Tests.

## Acceptance Criteria

- [x] Triggers made from events, conditions and actions, including if / then / else, loops, and units picked in a region
- [x] Variables (with arrays) made, changed and deleted
- [x] The JASS they become, shown in the code view
- [x] Saved into DAoW 5.4b's protected script and played by the game:
  - [x] a map-initialization message shows
  - [x] a periodic trigger pays gold
  - [x] a chat message makes three footmen in a region
  - [x] a second chat message kills the units picked in that region
  - [x] their deaths are counted into a variable through if / then
  - [x] no script errors
- [x] The blocks read back from the saved copy, and the written JASS taken out of its script; saving again writes them once
- [x] The map's own triggers listed; one switched off; a function rewritten, which the game then runs
- [x] Every change undoable
- [x] Checking finds missing regions, triggers with no events, and JASS that doesn't parse
- [x] The panel driven headless in the tests, and seen in the window (screenshots, not committed)

## Notes

- **JASS, not Lua:** issue 905 asked for Lua as the canonical form, with the GUI as a view of it. This pass writes JASS instead, as the World Editor does, so an edited map stays playable in WC3 itself. The blocks are the canonical form, kept in `war3mapEditor.lua`. The JASS is generated from them and never parsed back into blocks.
- **The map's triggers stay code:** a protected script has no GUI form to recover. Its triggers are edited as code, a function at a time.
- **Tests:** `src/tests/test_trigger_editor.lua` (70 tests).
