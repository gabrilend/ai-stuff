# Archive: WoW-Style Profession System (2026-01-07)

**Archived Date:** 2026-01-07
**Reason:** Project pivot from WoW/AzerothCore integration to pure WC3 engine
**Status:** Complete implementation, archived for future reference

---

## Context

This archive contains a complete WoW-style profession system that was implemented as part of an exploration into dual WC3/WoW gameplay modes. The work was completed across 5 sub-issues (702a-702e) with comprehensive implementations and tests.

**What Changed:** On 2026-01-07, the project pivoted from a WoW/AzerothCore integration architecture to a pure WC3 emulation approach (see `docs/postmortem-azerothcore-integration.md`). This profession system, while well-designed and fully functional, represents WoW-specific complexity that doesn't align with WC3's simpler harvest mechanics.

---

## What Was Implemented

### Issue 702a: Core Profession Component
- Profession registry with learn/unlearn mechanics
- Skill progression (0-max with configurable caps)
- Cooldown tracking with periodic updates
- Specialization support
- 73 passing tests

**Files:**
- `src/runtime/systems/professions.lua` (769 lines)
- `src/tests/test_professions.lua` (1,649 lines)

### Issue 702b: Gathering Professions
- Gatherable node component (minerals, plants, corpses, wood, water)
- Node depletion and respawn system
- Profession definitions (Mining, Herbalism, Skinning, Lumberjacking, Fishing)
- Node templates with WC3 mode support
- 31 passing tests

**Files:**
- `src/runtime/systems/gathering.lua` (702 lines)
- `src/tests/test_gathering.lua` (748 lines)

### Issue 702c: Crafting Professions
- Crafting action flow with channel time
- Profession definitions (Blacksmithing, Alchemy, Engineering, etc.)
- Recipe difficulty and skill-up mechanics
- Crafting station component
- Batch crafting support
- 36 passing tests

**Files:**
- `src/runtime/systems/crafting.lua` (667 lines)
- `src/tests/test_crafting.lua` (904 lines)

### Issue 702d: Recipe and Schematic System
- Recipe registry with requirements and difficulty
- Schematic discovery and learning
- Recipe filtering and searching
- WC3 and WoW mode configurations
- 40 passing tests

**Files:**
- `src/runtime/systems/recipes.lua` (763 lines)
- `src/tests/test_recipes.lua` (1,055 lines)

### Issue 702e: WoW-Mode Configuration
- Skill tier system (6 tiers: Apprentice → Grand Master)
- Primary profession limits (2 max)
- Specialization system (Blacksmithing, Engineering, Alchemy, etc.)
- Profession perks (passive bonuses, abilities)
- Profession trainer component
- 28 passing tests

**Files:**
- `src/runtime/configs/wow_profession.lua` (750+ lines)
- `src/tests/test_wow_profession.lua` (600+ lines)

---

## Statistics

| Metric | Count |
|--------|-------|
| **Issues Completed** | 5 (702a-702e) |
| **Source Files** | 5 |
| **Test Files** | 5 |
| **Total Lines of Code** | ~3,700 (source) |
| **Total Test Lines** | ~5,000 |
| **Passing Tests** | 208 |
| **Test Coverage** | Comprehensive |

---

## Why It Was Archived

**WC3 Reality:**
- WC3 doesn't have "professions" in the WoW sense
- Gathering is handled by unit abilities (Harvest gold, Gather lumber)
- No skill progression 1-300
- No trainers, specializations, or profession perks
- Workers are disposable units, not progression characters

**WoW Complexity:**
- Primary profession limits
- Trainer visits for skill cap increases
- Specialization choices with exclusive recipes
- Passive bonuses and profession abilities
- Recipe discovery and schematics

This system was designed for a WoW/WC3 hybrid that's no longer the project direction. The new mission is **pure WC3 emulation** - preserving custom maps as they were, not transforming them into MMO mechanics.

---

## Potential Future Use

This work is **not discarded**, merely archived. It could be resurrected if:

1. **WC3 Custom Map Need:** A popular WC3 custom map implements WoW-style professions
2. **Community Request:** Players request WoW-style profession mechanics
3. **Future Expansion:** After core WC3 engine is complete, optional "enhanced" mode
4. **Different Project:** Someone forks to build the WoW/WC3 hybrid originally envisioned

---

## What Survives

**Concept that lives on in WC3 engine:**
- Gathering mechanics (simplified to WC3 harvest abilities)
- Resource collection from nodes
- Unit-based gathering (workers collect gold/lumber)

**What doesn't transfer:**
- Skill progression systems
- Trainer NPCs
- Specialization choices
- Profession limits
- Recipe discovery

---

## Archive Contents

```
archives/2026-01-07-wow-professions/
├── README.md (this file)
├── issues/
│   ├── 702-profession-system.md (root issue)
│   ├── 702a-core-profession-component.md
│   ├── 702b-gathering-professions.md
│   ├── 702c-crafting-professions.md
│   ├── 702d-recipe-schematic-system.md
│   └── 702e-wow-mode-configuration.md
└── src/
    ├── runtime/
    │   ├── systems/
    │   │   ├── professions.lua
    │   │   ├── gathering.lua
    │   │   ├── crafting.lua
    │   │   └── recipes.lua
    │   └── configs/
    │       └── wow_profession.lua
    └── tests/
        ├── test_professions.lua
        ├── test_gathering.lua
        ├── test_crafting.lua
        ├── test_recipes.lua
        └── test_wow_profession.lua
```

---

## Git History

Commits archived from worktree `issue-702a`:

```
fae77dfd Issue 702e: Add WoW-mode profession configuration
2e2f0503 Issue 702b: Add gathering profession system
ce4b01cc Issue 702c: Add crafting profession system
8a182d55 Issue 702d: Add recipe and schematic system
a631e288 Issue 702a: Complete profession system with registry and cooldowns
```

---

## Lessons Learned

1. **Validate core before expanding:** We built WoW profession systems before completing basic WC3 map execution
2. **Mission clarity matters:** The AzerothCore integration was a beautiful detour from the core mission
3. **Complete work isn't wasted:** This archive represents quality research and implementation patterns
4. **Pivot when clarity strikes:** Better to archive 6 hours of work than months of misaligned effort

---

## Related Documents

- `docs/postmortem-azerothcore-integration.md` - Why we pivoted away from WoW integration
- `docs/wc3-engine-architecture.md` - Pure WC3 engine architecture (current direction)
- `notes/vision` - Original emulator philosophy
- `issues/CRITICAL-PATH.md` - Decision points and pivot documentation

---

**Status:** Preserved for posterity. May it serve future projects well.

**Motto:** *"Preserve the garden. Honor the creativity. Keep the maps alive."*
