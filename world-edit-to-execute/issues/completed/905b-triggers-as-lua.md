# Issue 905b: Triggers as Lua — the Code View That Edits

**Phase:** 9 (editor)
**Type:** Implementation
**Priority:** Critical
**Parent:** 905 (trigger editor)
**Dependencies:** 905a (blocks written as JASS)

---

## Current Behavior

- **Blocks only:** triggers are edited as blocks.
- **Read-only code:** the code view shows only the JASS the blocks become.
- **Missing from 905's design:**
  - editable Lua with two-way sync between the blocks and the code;
  - unrecognised code kept as custom script;
  - autocomplete and error highlighting;
  - categories.

## Intended Behavior

### The Lua form (`editor/trigger_lua.lua`)

Every trigger has a Lua form, one to one with its blocks. Editing either view changes the same trigger:
- **A trigger:** `trigger "Name" { category, on, comment, events = {...}, conditions = {...}, actions = {...} }`.
- **A block:** its kind called with its parameters, e.g. `unit_type_is { unit = "dying", unit_type = "hfoo" }`.
- **Control blocks:** their parts are lists of blocks (`if_conditions`, `then_actions`, `else_actions`, `loop_actions`).
- **Expressions:** `expr "..."` puts a JASS expression in any slot.
- **Custom script:** a plain string where a condition or action goes is kept as a custom-script block. This is 905's "unrecognised code becomes a custom code block".
- **Variables:** `variable "Name" { type, initial, array, size }`.

### Reading it back

- **Why and where:** errors say why and give the line. That covers Lua syntax errors, unknown block kinds (listing the ones that exist), wrong shapes, and a name taken by another trigger.
- **As data only:**
  - the only globals are `trigger`, `variable`, `expr` and the block kinds;
  - no assignments;
  - an instruction limit, with LuaJIT's compiler turned off for that text, since compiled loops never call the limit's hook;
  - a library call such as `os.remove` is refused with a plain message.

### The editor

- **Methods:** `E:trigger_lua(t)` / `E:set_trigger_lua(t, text)` for one trigger; `E:triggers_lua()` / `E:set_triggers_lua(text)` for every trigger and variable, matched by name so existing triggers stay the same objects. Each apply is one step to undo.
- **Completion:** `E:trigger_words()` gives the words the code view completes: block kinds, parameters, unit roles, and the map's triggers, variables, regions, cameras and sounds.
- **JASS stays read only:** the JASS saved into the map is still made from the blocks.

### The panel

- **Code views:** "Code" opens the trigger's Lua. Apply (or Ctrl+Enter) keeps it, and "JASS" switches to the read-only JASS. "Lua (all)" on the left edits every trigger and variable as one text.
- **Mistakes:** a mistake keeps the view open, marks its line in red and shows why under the text.
- **Categories:** each trigger has a category (typed). The list groups triggers by category under headers that fold.

### The text editor (`editor/textedit.lua`)

- **Lua highlighting** with `lang = "lua"`.
- **Completion:** once two characters of a word are typed, matching words show under the cursor. Tab takes the first, Ctrl+Space shows them, Esc hides them.
- **Error marking:** `T.error = { line, message }` marks a line.

## Acceptance Criteria

- [x] A trigger (with if/then/else, custom script, a picked-units loop, an expression) written as Lua and read back: the same JASS
- [x] Edited as Lua: the blocks, and so the JASS, follow; one step to undo
- [x] Errors: an unknown block reported with its line; broken Lua reported with its line; a taken name refused; a loop can't hang it; nothing outside can be reached
- [x] A string is custom script
- [x] Every trigger and variable at once: read back the same; a trigger and variable added in text; undone together
- [x] The panel: the Lua view, a mistake marked, completion taken with Tab, Ctrl+Enter applying, a category typed and folded, Lua (all)
- [x] Seen in the window: the Lua view coloured, with the completion list under the cursor

## Notes

- **Tests:** `src/tests/test_trigger_editor.lua` (95 tests; 25 new).
- **Why this Lua:** it's declarative, the blocks written as data, rather than the `trigger:on(...)` style 905's design sketched. Then every text the view accepts is exactly a set of blocks: there's nothing to parse back from arbitrary code, and nothing is lost either way. Arbitrary JASS still has a place, as the strings that become custom script.
- **Still open in 905:**
  - drag and drop in the block tree;
  - reading `war3map.wtg` / `war3map.wct` (none of the 16 test maps has them);
  - trigger debugging (breakpoints).
