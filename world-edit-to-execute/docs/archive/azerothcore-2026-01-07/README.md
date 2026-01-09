# AzerothCore Integration Archive (2026-01-07)

**Status:** Archived
**Date:** 2026-01-07
**Lifespan:** ~6 hours (design phase only)
**Reason:** Architectural pivot to pure WC3 engine

---

## What This Archive Contains

These documents represent a comprehensive exploration of integrating Warcraft III custom maps with the AzerothCore (WotLK) server emulator. The vision was to create an MMO platform where WoW players could enter WC3 map instances and play with dual-mode gameplay (Warlord RTS + Hero RPG).

**Design Documents (2,700+ lines):**

1. **azerothcore-integration-architecture.md** (400 lines)
   - Overall system architecture
   - Data flow from .w3x to AC server
   - Component ownership (what AC handles vs our engine)
   - Open questions about fork/Eluna, map instances, hero persistence

2. **client-architecture.md** (500 lines)
   - Dual-protocol design (WoW + custom)
   - Dual-view rendering (WC3 tactical + WoW RPG cameras)
   - Phase 5 split into 5A/5B/5C
   - Warlord Mode vs Hero Mode UI designs

3. **data-conversion-pipeline.md** (600 lines)
   - 5 conversion modules (terrain, units, items, doodads, triggers)
   - Full conversion algorithms with code examples
   - Coordinate system mappings (WC3 ↔ WoW)
   - CLI tool design for automated conversion

4. **custom-ability-bridge.md** (700 lines)
   - Pure Eluna vs AC Fork comparison
   - Ability classification system (4 complexity levels)
   - Code generation for both Lua and C++
   - Chain Lightning example implementation
   - Performance analysis and migration criteria

5. **phase-reorganization.md** (500 lines)
   - Proposed phase restructuring
   - Phase 4 audit (deprecate AC-redundant systems)
   - New phases for data conversion and ability bridge
   - Migration plan, impact analysis, risk mitigation

**Total Design Work:** ~6 hours, 2,700+ lines of documentation

---

## Why This Was Abandoned

See: `docs/postmortem-azerothcore-integration.md` for full analysis.

**Summary:**
- **Complexity:** Too many moving parts (AC server + custom client + conversion pipeline)
- **Dependency:** External server emulator (AzerothCore) with monthly merge burden
- **Mission Drift:** Transforming WC3 maps instead of preserving them
- **Clarity:** User's realization: "Why am I doing this instead of just emulating WC3 maps?"

**The Pivot:**
Focus on pure WC3 engine - play .w3x maps directly with community assets, no server dependency, following ROM emulator legal precedent.

---

## What Was Learned

Even in failure, valuable insights:

### Technical Knowledge

1. **Coordinate Systems**
   - WC3 uses center-origin, 128 units/tile
   - WoW uses different scaling and axis conventions
   - Conversion formulas documented

2. **Protocol Design**
   - WoW client protocol structure studied
   - Custom protocol extension patterns explored
   - Graceful fallback strategies designed

3. **Ability Systems**
   - WC3 ability classification (4 levels)
   - Code generation patterns (Lua + C++)
   - Performance profiling methodology

4. **Data Conversion**
   - Terrain: .w3e → .adt heightmap conversion
   - Units: WC3 object data → SQL templates
   - Triggers: JASS → Eluna transpilation

### Architectural Lessons

**What to avoid:**
- Dependency on external systems before validating core
- Designing integrations before building the engine
- Complexity before simplicity
- Transformation before preservation

**What to keep:**
- Dual-view camera system (still valid for pure WC3)
- Phase-based development approach
- Testing methodology (vertical slice)
- Community asset replacement philosophy

---

## Resurrection Clause

This design is not dead - merely archived.

**Conditions for resurrection:**

1. ✅ Pure WC3 engine is complete (first playable map working)
2. ✅ Community requests WoW integration (>100 verified requests)
3. ✅ Maintainer team grows (>3 active contributors)
4. ✅ AzerothCore partnership (official collaboration)

If all four conditions are met, this architecture may be resurrected.

Until then: **Preserve the garden, not transform it.**

---

## Using This Archive

**If you're reading this in the future:**

This archive contains research that may be valuable if:
- You want to integrate WC3 with a different server (not just AC)
- You need coordinate conversion formulas (WC3 ↔ WoW)
- You're designing ability systems (classification patterns)
- You're building a dual-protocol client
- You need data pipeline architecture examples

**Treat these as reference, not gospel.**

The designs were never implemented or validated. They represent hypothetical architecture that seemed sound on paper but was abandoned before reality-testing.

---

## Related Documents

- `docs/postmortem-azerothcore-integration.md` - Full post-mortem analysis
- `docs/wc3-engine-architecture.md` - Current pure WC3 engine design
- `notes/vision` - Original project vision (emulator philosophy)

---

**Archived By:** Claude Sonnet 4.5
**Date:** 2026-01-07
**Reason:** Mission realignment - pure WC3 preservation over MMO transformation

*"Sometimes the best architecture is the one you don't build."*
