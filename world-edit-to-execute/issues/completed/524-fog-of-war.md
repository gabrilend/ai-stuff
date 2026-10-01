# Issue 524: Fog of War

**Phase:** 5 (rendering) and 7 (gameplay: roadmap row 707)
**Type:** Implementation
**Priority:** High
**Dependencies:** 519 (combat), 520 (the map's script), 502d (fog rendering, planned)

---

## Current Behavior

Everything is visible to everyone: the player sees the whole map and every
unit on it, and units pick targets anywhere in their acquisition range.
The script's fog natives (FogEnable, fog modifiers, IsUnitVisible ...) do
nothing, and say everything is visible.

## Intended Behavior

- **Per player:** each player sees what WC3 would let it see. Ground is visible (seen now), fogged (seen before) or masked (never seen: black).
- **Drawing:** the world and the minimap are drawn that way.
- **Hidden units:** units out of sight aren't drawn or clickable, and can't be picked as targets.
- **The script's controls:** a map's script controls the fog with its natives.

## Suggested Implementation Steps

1. A visibility grid per player, lit by each unit's sight, with cliffs and trees in the way.
2. The script's natives: switches, modifiers, one-off states, questions.
3. A fog pass in the renderer; the minimap's fog; units hidden in the interface.
4. Combat only picks what it can see.
5. Tests: small cases on a made-up grid; DAoW with its script.

## Acceptance Criteria

- [x] Visible, fogged and masked per player, on the map's tile grid; explored ground stays fogged after units leave
- [x] Day and night sight radii (usid/usin, else stand-ins); ground units don't see onto or past higher cliff levels, nor past trees; flyers see over them
- [x] Shared vision from the script's alliances (force flags without a script)
- [x] FogEnable, FogMaskEnable, fog modifiers (rect, radius, loc; visible, fogged, masked; before or after units), SetFogState*, and the Is*Visible/Fogged/Masked questions work
- [x] The world is shaded by fog (black, dim, clear, soft-edged); the minimap too; unseen units aren't drawn, selectable, shown on the minimap or given health bars; buildings once seen stay in the fog
- [x] Units don't pick targets they can't see, and let go of targets lost in the fog
- [x] `test_vision.lua`: 50 tests; full suite passes

## Implementation Notes

**Date:** 2026-09-29

### Visibility (`demo/wc3map/vision.lua`)

The grid:

- **Cells:** the map's tile points, 128 WC3 units apart (DAoW 5.4b: 481 × 481).
- **Per player:** a count of sight sources per cell (uint16) and an explored flag (uint8), both FFI arrays made only for players that have sources.

Sight:

- **Sources:** each living unit of players 0–12, each lighting a circle of its sight radius.
- **Radius:** the map's day and night fields (usid, usin), else stand-ins by kind:

  | Kind | Day | Night |
  |------|-----|-------|
  | Units | 1400 | 800 |
  | Heroes | 1800 | 800 |
  | Buildings | 900 | 600 |
  | Towers | 1600 | 900 |

- **Night:** 18:00–6:00 by the game clock.

Blocking, for ground units:

- A cell on a higher cliff level than the unit's own isn't seen.
- Nor is anything whose line from the unit crosses a higher cell or a tree.
- Flyers see over both.
- The lines are precomputed per radius ("templates"): every offset in the circle, and the cells between it and the middle.

Cost:

- **Kept per unit:** each unit keeps the cells it lights. They're added to or taken from its owner's counts only when it moves to another cell, its radius changes, it dies, or it leaves the game.
- **Timing on DAoW 5.4b** (4,379 units, 3,389 sight sources):
  - The first update takes about 0.1 s.
  - Later updates, every quarter second, take about 9 ms.
  - The mask the renderer needs takes under 1 ms.
- **Dusk and dawn** recompute every unit once.

Queries:

- `state(p, x, y)`: 2 visible, 1 fogged, 0 masked.
- `sees(p, u)`: always for the player's own and sharers' units; others when in a visible cell and not invisible.
- **Buildings:** a building the local player has seen stays shown in the fog, where it was.

Sharing:

- **With a running script:** a player sees what its sharers see; players' `vision` alliances (ALLIANCE_SHARED_VISION) decide who shares.
- **Without one:** force flags decide, and they also start the script's alliances.

### The script's natives (`jass/natives/fog.lua`)

- **Switches:** FogEnable, FogMaskEnable, and the BJ On/Off forms.
- **Modifiers:**
  - Rect, radius and loc forms, with the BJ forms and bj_lastCreatedFogModifier.
  - "Visible" modifiers add sight.
  - "Fogged" and "masked" ones cover an area. Over the units' sight if made "after units", else only where no unit sees.
- **One-off states:** SetFogStateRect/Radius. Visible and fogged explore the area; masked forgets it.
- **Questions:** IsVisibleToPlayer, IsFoggedToPlayer, IsMaskedToPlayer (and Location forms), IsUnitVisible/Fogged/Masked/Invisible.
- **No longer no-ops:** these were counted among the VM's no-ops before; the old stand-ins are removed from `interface.lua` and `bj.lua`.

### Drawing

- **Fog pass** (`render/fog.c`):
  - With fog on, the 3D view is drawn into a colour and depth texture.
  - A last pass turns each pixel's depth back into a ground position (the inverse view-projection matrix, captured inside the 3D pass) and multiplies its colour by the fog texture there.
  - Shades: black for masked, 110/255 for fogged, clear for visible, filtered so the edges are soft.
  - So terrain, baked designs and models are all shaded the same, and the interface, drawn after, isn't.
  - It builds against raylib 5.5 and 5.0 (their framebuffer calls differ).
- **API:** `render.fog_set(w, h, x0, y0, cell, shades)` and `render.fog_off()`. `render.ui_image_update` refreshes an image (the minimap's fog layer, 128 × 128).
- **Map viewer:**
  - Pushes the local player's mask after each update.
  - Draws only units `game.shown(u)`; buildings are baked once seen.
- **HUD:** picking, health bars and minimap dots skip unseen units.
- **Switch:** `WC3_FOG=0` turns it all off.

### Combat

- **Picking targets:** a unit only picks a target its player can see.
- **Losing them:** it lets go of one lost in the fog, unless that target hit it in the last two seconds (so a unit shot from the dark still answers).

### Checked

- **Screenshots of DAoW 5.4b:**
  - Player 0's base clear in the black mask.
  - The ground the army has marched over dim behind it.
  - Higher ground shaded where it isn't seen.

### Not yet

- **Grid:** a finer grid than the tile grid (WC3's own fog is finer), and trees that are cut down still block.
- **Destructables:** occlusion heights from their data (only trees block).
- **Attackers:** WC3's brief reveal of an attacker to its victim; here the victim only answers for two seconds.
- **Buildings in the fog:** a building that dies in the fog vanishes at once; WC3 keeps the last-seen picture until seen again.
- **Computer players:** the AI (issue 521) still knows where everything is; only its units' target picking respects the fog.
- **Other effects:** detection, invisibility abilities, and sight bonuses from items and upgrades.
- **Terrain fog** (SetTerrainFogEx, the distance haze) is still a no-op: it's a different thing.
