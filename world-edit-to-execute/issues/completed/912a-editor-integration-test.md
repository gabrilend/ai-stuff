# Issue 912a: The Editor's Integration Test

**Phase:** 9 (editor)
**Type:** Testing
**Priority:** High
**Parent:** 912 (Phase 9 integration test)
**Dependencies:** 901-909 first passes, 911a, 911b

---

## Current Behavior

- **Separate tests:** each part of the editor has its own tests, mostly on DAoW:
  - `test_editor`, `test_trigger_editor`, `test_ai_editor`, `test_imports`;
  - `test_sound_editor`, `test_cameras_regions`, `test_new_map`.
- **No single workflow:** nothing takes one map through all of them, then saves, reopens and plays it.

## Intended Behavior

`src/tests/test_editor_integration.lua` covers issue 912's scenarios 1 (new map), 2 (object editing) and 5 (play-test), and the trigger half of 3, all on one map made from nothing.

### Made and edited

- **The map:** a two-player melee map, human against an orc computer.
- **Terrain:** a hill raised and painted, and a pond poured.
- **Objects:** a gold mine (a script unit) moved; a knight placed.
- **Object types:** a custom footman with 777 hit points and its own name, one placed.
- **New things:** a region, a camera (set from a view), and a sound whose file is imported.
- **Triggers:**
  - an integer variable;
  - entering the region counts a visit, shows a message and plays the sound;
  - a chat command applies the camera and pays 250 gold;
  - a victory condition fires once the region has been visited.
- **AI:** the orc's profile renamed, its first wave at 15 seconds.
- **Imports and music:** a texture imported; the map's music changed.

### Saved and opened again

- **Checks:** the whole script loads; every file written.
- **Read back:** the triggers, variable, region, camera and sound; the imports; the custom type; the raised and painted ground; the placed units (now the script's); the AI profile from the map.

### Played

- **As edited:** no script errors; the custom unit's hit points and name; the knight; the moved mine; the melee start; the new music; the edited AI read from the map.
- **The region trigger:** the knight walks into the region; the visit is counted, the message shown and the sound played.
- **The chat trigger:** the camera applied, and the gold paid.
- **The end:** the victory is won; the orc AI's first wave goes at the edited time.

### Found and fixed on the way

On a melee map, `MeleeStartingAI` started the stock melee AI, and a profile made in the AI editor (saved in the map) was never used.
- `ai/init.lua`: `start_script` now plays the player's own profile (the profiles folder's, or the map's) when there is one.
- `ai/faction.lua`: `find_profile` added.

### Demo

`issues/completed/demos/run_phase9.sh`:
1. makes a new map from the command line;
2. runs this test;
3. opens the editor's window on the new map.

## Acceptance Criteria

- [x] One map through every part of the editor: 44 checks, all passing
- [x] A melee map's AI-editor profile replaces the stock melee AI
- [x] The phase demo script

## Notes

Still open in 912:
- Scenario 3's code-view round trip (the GUI and Lua sync of 905).
- Scenario 4: the unified format (911).
- Scenario 6: campaigns (910).
- A play-test that returns to the editor with its state (the play-test runs the saved copy in a separate window).
