# Issue 510: Dual Perspective UI System

**Phase:** 5 - Rendering
**Type:** Feature
**Priority:** High
**Dependencies:** 506 (UI Framework)

---

## Current Behavior

No game-specific UI exists. The UI framework (506) provides primitives but no
game interface. Players cannot control units, view stats, or interact with the
game world through an interface.

---

## Intended Behavior

A dual-perspective UI system that adapts to how the player is experiencing the game:

### Warlord Mode (RTS Perspective)
Playing as commanders like **Thrall**, **Arthas**, **Jaina** - controlling armies
from above. Classic WC3 experience.

```
┌─────────────────────────────────────────────────────────────────┐
│ [Gold: 1250]  [Lumber: 800]  [Food: 45/100]      [12:34] Day    │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│                                                                 │
│                    ISOMETRIC BATTLEFIELD                        │
│                    (Multi-unit control)                         │
│                                                                 │
│                                                                 │
├──────────────────┬───────────────────┬──────────────────────────┤
│    [MINIMAP]     │   UNIT PORTRAIT   │    COMMAND GRID          │
│                  │   Name: Grunt     │   [Q][W][E][R]           │
│    ┌───────┐     │   HP: ████░░ 80   │   [A][S][D][F]           │
│    │   ▲   │     │   Armor: 2        │   [Z][X][C][V]           │
│    │  ●●●  │     │   Attack: 12-15   │                          │
│    └───────┘     │                   │   [Selected: 12 units]   │
└──────────────────┴───────────────────┴──────────────────────────┘
```

### Hero Mode (RPG Perspective)
Playing as a single hero - **your** character in the world. WoW-style experience.

```
┌──────────────────────────────────────────────────────┬──────────┐
│ [Portrait]  Thrall          [Target] Ogre Mauler     │ MINIMAP  │
│ HP: ████████████░░ 2450/2800                         │          │
│ MP: ██████░░░░░░░░ 800/1400                          │ ┌──────┐ │
│ XP: ██████████░░░░ Level 42                          │ │  ▲   │ │
├──────────────────────────────────────────────────────┤ │ ●    │ │
│                                                      │ └──────┘ │
│                                                      ├──────────┤
│                                                      │ QUESTS   │
│              THIRD-PERSON / OVER-SHOULDER            │ ○ Quest1 │
│              (Single character control)              │ ○ Quest2 │
│                                                      │          │
│                                                      ├──────────┤
│                                                      │ BUFFS    │
│                                                      │ [⚔][🛡]  │
├──────────────────────────────────────────────────────┴──────────┤
│  [1][2][3][4][5][6][7][8][9][0][-][=]     [Bags] [Menu] [Map]   │
│  ACTION BAR                                                      │
│  [Shift+1][Shift+2]...                                          │
└─────────────────────────────────────────────────────────────────┘
```

---

## Design Philosophy

### The Commander vs The Hero

| Aspect | Warlord (RTS) | Hero (RPG) |
|--------|---------------|------------|
| **Viewpoint** | Omniscient bird's-eye | Personal third-person |
| **Control** | Many units simultaneously | One character directly |
| **Information** | Army composition, resources | Character stats, inventory |
| **Camera** | Free scroll, zoom out | Follow character, zoom in |
| **Combat** | Select → Right-click | Hotkeys → Target |
| **UI Density** | Compact, efficiency-focused | Spacious, immersion-focused |
| **Narrative Feel** | "My forces advance" | "I advance" |

### When Each Mode Activates

The perspective can be:
1. **Map-defined**: Some maps force one perspective
2. **Player-chosen**: Toggle between modes
3. **Context-aware**: Zoom level switches mode
4. **Hybrid**: Hero in personal combat, warlord for army maneuvers

---

## Sub-Issues

| ID | Name | Description |
|----|------|-------------|
| 510a | Warlord Mode UI | RTS interface: command grid, multi-select, group hotkeys |
| 510b | Hero Mode UI | RPG interface: action bars, character panel, inventory |
| 510c | Perspective Switching | Mode transitions, camera handoff, UI morph |
| 510d | Shared UI Components | Elements common to both: minimap, chat, alerts |
| 510e | UI State Persistence | Remember layouts, hotbar configs, preferences |

---

## Integration with AzerothCore

Per OQ-003/004 decision (API-driven integration):

```
┌─────────────────────────────────────────────────────────┐
│              world-edit-to-execute                      │
│                   (game state)                          │
│                                                         │
│  ┌─────────────┐           ┌─────────────────────────┐  │
│  │ Unit/Army   │           │ Character/Inventory     │  │
│  │ State       │           │ State                   │  │
│  └──────┬──────┘           └───────────┬─────────────┘  │
│         │                              │                │
└─────────┼──────────────────────────────┼────────────────┘
          │                              │
          ▼                              ▼
   ┌─────────────┐              ┌─────────────────┐
   │ Warlord UI  │              │ Hero UI         │
   │ (Raylib)    │              │ (Raylib or      │
   │             │              │  AzerothCore)   │
   └─────────────┘              └─────────────────┘
```

The same character data can be rendered as:
- A unit portrait in Warlord mode (Thrall commanding the Horde)
- A character sheet in Hero mode (Thrall the player character)

---

## Acceptance Criteria

- [ ] Warlord mode displays WC3-style RTS interface
- [ ] Hero mode displays WoW-style RPG interface
- [ ] Player can switch between perspectives
- [ ] Camera transitions smoothly between modes
- [ ] UI state persists across mode switches
- [ ] Both modes share common elements (minimap, chat)
- [ ] Keybindings adapt to current mode
- [ ] Unit tests for mode switching logic

---

## Notes

The brilliance of Warcraft's universe is that the same character can be both:
- A legendary commander leading thousands (WC3)
- An individual hero on a personal quest (WoW)

Thrall is the Warchief ordering his armies, AND the shaman throwing lightning.
Arthas is the Lich King commanding the Scourge, AND the death knight swinging
Frostmourne.

This dual nature is what we're capturing in the UI system.

---

## Related Documents

- issues/506-build-ui-framework.md (foundation)
- issues/500-dual-interface-rendering-considerations.md (design context)
- issues/CRITICAL-PATH.md (OQ-003/004 decisions)
- notes/vision (emulator philosophy)

---

## Generated Sub-Issues

*Created on 2025-12-29*

- 510a-warlord-mode-ui.md - RTS interface with command grid, multi-select
- 510b-hero-mode-ui.md - RPG interface with action bars, character panel
- 510c-perspective-switching.md - Mode transitions, camera handoff
- 510d-shared-ui-components.md - Minimap, chat, alerts, tooltips
- 510e-ui-state-persistence.md - Save/load layouts, keybinds, preferences

