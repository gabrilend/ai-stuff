# Issue 518: The WC3 Interface

**Phase:** 5
**Type:** Implementation
**Priority:** High
**Dependencies:** 517 (maps drawn with designs), 516c (locomotion)

---

## Current Behavior

A loaded map can be looked at but not played: there is no interface, no
selection, no orders; the viewer's only overlay is a status line.

## Intended Behavior

WC3's in-game interface over a loaded map, with the buttons the game has,
filled from the map's own data where it has it:

- **Top bar:** Quests (F9), Menu (F10), Allies (F11), Log (F12); the day
  clock (sun by day, moon by night); gold, lumber, food and upkeep
- **Console:** minimap (terrain, every unit in its colour, the camera's
  view, pings) with its five buttons (Signal, Terrain, Ally Colours,
  Creeps, Formation Movement; Alt+G/T/A/R/F); portrait (the unit's design,
  live in 3D); hit points and mana; information (name, level or class,
  owner, damage, armour, hero attributes) or the group's icons; the
  six-slot inventory; the 4 x 3 command card with hotkeys and tooltips
- **Hero buttons** (F1-F3) and the **idle-worker** button (F8)
- **Panels:** Quests (the map's CreateQuestBJ titles), Menu (Save, Load,
  Options, Help, Tips, End Game, Return to Game), Allies (every player,
  allied by the map's forces), Log
- **Selecting:** click, drag box (your units, units before buildings, up
  to 12), Shift adds, Tab cycles subgroups, Ctrl+digit sets a control
  group and the digit recalls it (twice: the camera goes there)
- **Orders:** Move (M), Stop (S), Hold Position (H), Attack (A), Patrol
  (P) by button or hotkey then a click on the ground or minimap; right
  click moves, or attacks an enemy; Esc cancels; units walk by WC3's
  movement rules (516c) in formation

## Acceptance Criteria

- [x] Console parts laid out as WC3's, on screen, not overlapping
- [x] Command card: stock commands in WC3's places; the map's abilities,
      trained units and structures with its names, hotkeys, placements and
      tooltips; Build and Hero Abilities sub-menus with Cancel bottom right
- [x] Selection, orders, control groups, hero and idle-worker keys, panels
      and minimap buttons work
- [x] `test_wc3_interface.lua`: 68 tests pass; full suite (107 files) passes
- [x] Checked by screenshot on DAoW 5.4b: building, hero with tooltip,
      worker's build menu, a 12-unit group ordered to move, each panel

## Implementation Notes

**Date:** 2026-09-29

### 518a: engine side (C)

`src/render/ui2d.{c,h}`: `render.ui_rect/frame/line/tri/circle/text/
text_width/image_load/image/portrait/screen`. The portrait is a small 3D
view rendered to a texture each frame from a third geometry layer
(`render.geo_target("portrait")`). `scene_viewer.c` gives scenes a
`viewer` table (camera get/set, world-to-screen, screen-to-ground, mouse,
keys, modifiers, quit) and calls `scene_ui()` after the 3D pass. A scene
with an interface owns the keyboard (letters are hotkeys, Esc cancels), so
the camera pans with the arrow keys and the screen edges, as in WC3.
`GEO_MAX_DYNAMIC` is now 65536: mobile units are drawn each frame near
the camera so they can move; doodads and buildings stay baked.

### 518b: the interface (Lua, `src/ui/wc3/`)

`layout.lua` (where everything sits), `icons.lua` (drawn glyphs in the
geometry kit's style; WC3's icon images are in the owner's game data),
`commands.lua` (the card), `hud.lua` (state, input, drawing), `names.lua`
(stock unit and ability names, and what stock workers build and buildings
train).

**From memory, labelled so in the code:** the stock commands' card places
and hotkeys, stock names, the stock build and train lists, the upkeep
thresholds (50 / 80 food), the 8-minute day starting at 8:00, and the
500 gold / 150 lumber melee start. Everything the map defines itself
comes from its object data: on DAoW 5.4b, 690 custom units list their
abilities and 745 custom abilities have names (715 hotkeys, 399 button
places, their tooltips). Tooltips show the map's text as written;
placeholders such as `<AUfn,DataB2>` stay, since filling them needs the
stock ability data.

The first test run found a bug the screenshots hadn't: a panel key opened
its panel but pressing it again didn't close it (`x and nil or y` is
always `y` in Lua).

### 518c: the map game state (`src/demo/wc3map/game.lua`)

Units with display names and whatever stats the map defines (hit points,
mana, damage, armour, level, hero attributes, speed, turn rate, food);
the command card's data lookups; orders carried out with
`runtime/locomotion.lua` over the ground (straight lines; no pathfinding
around cliffs yet), groups keeping their formation; the clock; players
and forces; quests; the minimap picture.

### Not yet

- Training, building, abilities, gathering, repair and the rally point
  are shown as the map defines them; pressing them says "not simulated in
  this viewer yet" in the message area.
- No combat: Attack walks to the point.
- Hit points of stock units show "- / -" (no stock data here).
- Save, Load, Options, Help and Tips answer "not in this viewer yet".

---

## Note (2026-09-29): building it elsewhere

Found while writing the build steps for the owner:

- `scene_viewer.c` used `GetScreenToWorldRay`, which raylib added in 5.5;
  it now uses `GetMouseRay` on older raylib (built against 5.0 and 5.5).
- `src/mpq/stormlib.lua` only looked for `libstorm.so` at the owner's
  path; it now tries the loading checkout's `deps/` first, and
  `STORMLIB_PATH` overrides. A fresh checkout's `run-map` loads and draws
  DAoW 5.4b with the owner's path hidden.
