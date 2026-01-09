# WoW Mode Issues Archive (2026-01-08)

**Status:** Archived
**Date:** 2026-01-08
**Reason:** Architectural pivot to pure WC3 engine

---

## What This Archive Contains

These issues represent features designed for a hybrid WC3/WoW gameplay mode that combined:
- WoW world geography with WC3 RTS mechanics ("Warlord Mode")
- WoW-style progression systems (professions, attributes, combat)
- Dual-interface rendering (RTS tactical + social/MMO views)

**Total Issues:** 19 files

---

## Why These Were Archived

Following the 2026-01-07 architectural pivot (see `docs/postmortem-azerothcore-integration.md`), the project refocused on a **pure WC3 engine** that:
- Executes .w3x maps directly (ROM emulator approach)
- Uses community-created assets (no Blizzard IP)
- Supports LAN multiplayer (no Battle.net dependency)
- Targets standard WC3 gameplay first

These WoW-influenced features represent **future extensibility demonstrations**, not the MVP path.

---

## Archived Issue Categories

### 1. Warlord Mode Design (000-005)
Long-term research documents exploring hybrid WC3/WoW gameplay:
- `000-warlord-mode-design-compendium.md` - Core concept and philosophy
- `001-combat-system-design.md` - Combat mechanics
- `002-caravan-economy-design.md` - Economy systems
- `003-patrol-raid-system-design.md` - Patrol and raid mechanics
- `004-warlord-interface-design.md` - Interface design
- `005-class-gem-system-design.md` - Progression systems

**Type:** Design research / pondering documents
**Status:** Never implemented, conceptual exploration only

### 2. Profession System (702 series)
WoW-style crafting and gathering professions:
- `702a-core-profession-component.md` - Core profession component
- `702d-recipe-schematic-system.md` - Recipe system
- `702e-wow-mode-configuration.md` - WoW mode configuration
- `702f-wc3-mode-configuration.md` - WC3 mode configuration (kept WC3 compat)
- `702g-profession-ui-abstraction.md` - Profession UI

**Type:** Implementation issues (unimplemented)
**Status:** Created 2026-01-08, never started

### 3. Dual Interface Rendering (500, 510 series)
Support for both RTS tactical and social/MMO interface modes:
- `500-dual-interface-rendering-considerations.md` - Design considerations
- `510-dual-perspective-ui-system.md` - Dual perspective system
- `510a-warlord-mode-ui.md` - Warlord (RTS) UI
- `510b-hero-mode-ui.md` - Hero (social) UI
- `510c-perspective-switching.md` - Camera/perspective toggle
- `510d-shared-ui-components.md` - Shared UI components
- `510e-ui-state-persistence.md` - UI state persistence

**Type:** Implementation issues (partially designed)
**Status:** Phase 5 (Rendering), superseded by pure WC3 camera system

---

## What Was Preserved

The pure WC3 engine retained these concepts:
- **Dual-camera system** - WC3 tactical (default) + optional 3D adventure camera
- **F5 camera toggle** - Switching between camera modes
- **Community assets** - Asset pack system for custom visuals
- **Phase-based development** - Incremental testing approach

---

## Resurrection Clause

These issues are **not deleted**, merely archived. They may be revived if:

1. ✅ Pure WC3 engine is complete (first playable map working)
2. ✅ Community requests WoW-mode features (>50 verified requests)
3. ✅ Maintainer team grows (>3 active contributors)
4. ✅ Clear use case emerges (not just "it would be cool")

Until then: **Build the garden before expanding it.**

---

## Using This Archive

**If you're reading this in the future:**

These documents may be valuable if:
- You want to add WoW-influenced features to the engine
- You're designing hybrid RTS/MMO gameplay
- You need examples of profession or attribute systems
- You're exploring dual-interface rendering

**Treat these as reference, not gospel.**

The designs were never implemented or validated. They represent hypothetical features that seemed interesting but weren't prioritized for the MVP.

---

## Related Documents

- `docs/postmortem-azerothcore-integration.md` - Why we pivoted from AC integration
- `docs/wc3-engine-architecture.md` - Current pure WC3 engine design
- `docs/archive/azerothcore-2026-01-07/` - Earlier AC integration archive
- `issues/progress.md` - Current phase status and priorities

---

**Archived By:** Claude Sonnet 4.5
**Date:** 2026-01-08
**Reason:** Focus on pure WC3 MVP before extensibility features

*"First make it work, then make it fancy."*
