# Phase Reorganization Proposal

**Status:** Design Document
**Created:** 2026-01-07
**Purpose:** Restructure project phases to align with AzerothCore integration architecture

---

## Executive Summary

Following the architectural clarification that world-edit-to-execute is a **WC3 map data pipeline and custom client** (not a standalone game engine), the current phase structure needs reorganization.

**Key Changes:**
1. **Phase 4 (Runtime)** - Much of this is now redundant (AC handles game state)
2. **Phase 5 (Rendering)** - Split into 3 client-focused phases (5A/5B/5C)
3. **New Phase 6** - Data Conversion Pipeline (WC3 → AC format)
4. **New Phase 7** - Custom Ability Bridge (Eluna script generation)
5. **Original Phase 6-9** - Renumbered to 8-11

This document proposes the new structure and migration plan.

---

## Current Phase Structure (Before Reorganization)

| Phase | Title | Issues | Status |
|-------|-------|--------|--------|
| 0 | Tools - Issue Management | 7 | Complete ✓ |
| 1 | Foundation - File Format Parsing | 12 | In Progress (8/12) |
| 2 | Data Model - Game Objects | 8 | Pending |
| 3 | JASS Bridge - Script Execution | 8 | Pending |
| 4 | Runtime - Basic Engine Loop | 34 | Complete ✓ |
| 5 | Rendering - Visual Abstraction | 55 | Pending |
| 6 | Integration - Map Loading | 6 | Pending |
| 7 | Gameplay - Core Mechanics | 7 | Pending |
| 8 | Optimization - Performance | 6 | Pending |
| 9 | Polish - User Experience | 5 | Pending |

**Total:** 148 issues across 10 phases

---

## Proposed Phase Structure (After Reorganization)

| Phase | Title | Issues | Status | Notes |
|-------|-------|--------|--------|-------|
| 0 | Tools - Issue Management | 7 | Complete ✓ | No change |
| 1 | Foundation - File Format Parsing | 12 | In Progress | No change |
| 2 | Data Model - Game Objects | 8 | Pending | No change |
| 3 | JASS Bridge - Script Execution | 8 | Pending | Modified scope |
| 4 | Runtime - **AC Integration Layer** | 15 | Needs Review | Reduced from 34 |
| 5A | Client - Core & WoW Protocol | 20 | Pending | Split from Phase 5 |
| 5B | Client - Dual-View Rendering | 25 | Pending | Split from Phase 5 |
| 5C | Client - Custom Protocol | 10 | New | Custom protocol extensions |
| 6 | Data Conversion - WC3 → AC | 12 | New | Terrain, units, items, etc. |
| 7 | Custom Ability Bridge | 8 | New | Eluna script generation |
| 8 | Integration - Map Loading | 6 | Pending | Renumbered from 6 |
| 9 | Gameplay - Core Mechanics | 7 | Pending | Renumbered from 7 |
| 10 | Optimization - Performance | 6 | Pending | Renumbered from 8 |
| 11 | Polish - User Experience | 5 | Pending | Renumbered from 9 |

**Total:** ~143 issues across 13 phases (some Phase 4 issues deprecated, new issues added)

---

## Detailed Phase Changes

### Phase 3: JASS Bridge - Modified Scope

**Original Scope:**
- Execute JASS scripts in standalone engine
- Implement WC3 native functions
- Handle trigger execution

**New Scope:**
- Transpile JASS → Lua (still needed for Eluna)
- Convert WC3 natives → AC/Eluna API calls
- Generate Eluna trigger scripts (not runtime execution)

**Reason:** JASS execution happens in Eluna on AzerothCore, not in our standalone runtime.

**Issues to Modify:**
- 301: JASS parser → Keep (still need to parse for transpilation)
- 302: JASS interpreter → **Replace with JASS → Lua transpiler**
- 303: Native function implementation → **Replace with AC API mapping**
- 304-308: Keep but adjust to focus on code generation, not runtime execution

---

### Phase 4: Runtime - Reduced to AC Integration Layer

**Original Scope (34 issues):**
- Game loop
- Entity Component System (ECS)
- Pathfinding
- Movement and collision
- Resource management
- Player state tracking

**New Scope (15 issues):**
- **Keep:** Client-side prediction (ECS for local entity state)
- **Keep:** Client-side pathfinding preview (show path before moving)
- **Keep:** Local resource tracking (for UI display before server sync)
- **Remove:** Server-authoritative state (AC handles this)
- **Remove:** Combat calculations (AC + Eluna handle this)
- **Remove:** Multiplayer synchronization (AC's job)

**Issues to Deprecate:**

| Issue | Title | Reason |
|-------|-------|--------|
| 401c | Tick-based game loop | AC has this |
| 402 | ECS serialization | Server state in AC database |
| 403d | Alliance faction logic | AC handles factions |
| 404c | Resource transaction validation | AC authoritative |
| 405c | Collision resolution | AC navmesh handles this |
| 406 | Multiplayer state sync | AC networking |
| 407 | Player input handling | Client-side (move to Phase 5A) |

**Issues to Keep (Modified):**

| Issue | Title | New Purpose |
|-------|-------|-------------|
| 401a-b | Game loop basics | Client render loop (not game state loop) |
| 402a-b | Basic ECS | Client-side entity cache |
| 403a-c | Unit types | Match to AC creature types |
| 404a-b | Resource types | UI display models |
| 405a-b | Pathfinding | Client-side path preview |

**New Issues for Phase 4:**

| Issue | Title | Description |
|-------|-------|-------------|
| 409 | AC client library | WoW protocol implementation |
| 410 | Entity state sync | Receive AC updates, update local cache |
| 411 | Client prediction | Predict movement before server confirms |
| 412 | Lag compensation | Smooth movement with network latency |

**Revised Total:** ~15 issues (7 deprecated, 8 kept, 4 new)

---

### Phase 5A: Client Core & WoW Protocol

**Scope:** Basic client that connects to vanilla AzerothCore servers

**Issues (from original Phase 5):**

| Issue | Title | Original Phase 5 Issue |
|-------|-------|------------------------|
| 5A01 | Auth protocol | 501a |
| 5A02 | World protocol | 501b |
| 5A03 | Chat protocol | 501c |
| 5A04 | Character management | 502a |
| 5A05 | Map rendering | 502b |
| 5A06 | Entity rendering | 503a |
| 5A07 | Animation system | 503b |
| 5A08 | Asset loading | 504 |
| 5A09 | Model format support | 505a |
| 5A10 | Texture system | 505b |
| 5A11 | Basic UI framework | 506a |
| 5A12 | Chat UI | 506b |
| 5A13 | Target frames | 506c |
| 5A14 | Action bars | 506d |

**New Issues:**

| Issue | Title | Description |
|-------|-------|-------------|
| 5A15 | WoW .dbc parsing | Read client database files |
| 5A16 | .adt map rendering | Display AC terrain |
| 5A17 | Creature display | Render NPCs from server |
| 5A18 | Network buffering | Handle packet queues |
| 5A19 | Input handling | Keyboard/mouse → protocol |
| 5A20 | Debug console | In-game command interface |

**Total:** 20 issues

**Acceptance Criteria:**
- ✓ Can connect to vanilla AC server
- ✓ Can create/select character
- ✓ Can see terrain and NPCs
- ✓ Can move around world
- ✓ Can chat
- ✓ Basic UI functional (target frame, chat, action bars)

---

### Phase 5B: Client Dual-View Rendering

**Scope:** Add WC3-style camera and dual-view switching

**Issues (from original Phase 5):**

| Issue | Title | Original Phase 5 Issue |
|-------|-------|------------------------|
| 5B01 | Camera system | 507 |
| 5B02 | Minimap | 508 |
| 5B03 | UI theme system | 509 |
| 5B04 | Warlord Mode UI | 510a |
| 5B05 | Hero Mode UI | 510b |
| 5B06 | UI state management | 511 |
| 5B07 | HUD rendering | 512 |

**New Issues:**

| Issue | Title | Description |
|-------|-------|-------------|
| 5B08 | WC3 camera controller | Top-down tactical camera |
| 5B09 | WoW camera controller | Third-person RPG camera |
| 5B10 | Camera transition | Smooth F5 toggle animation |
| 5B11 | WC3 unit selection | Box select, ctrl-click groups |
| 5B12 | WoW targeting | Tab-target, mouseover |
| 5B13 | WC3 minimap style | RTS-style minimap with fog |
| 5B14 | WoW minimap style | RPG-style minimap with icons |
| 5B15 | Resource bars (WC3) | Gold, lumber, food display |
| 5B16 | Resource bars (WoW) | HP, mana, XP bars |
| 5B17 | Portrait rendering | Unit portraits in UI |
| 5B18 | Ability icons | Render spell icons on action bars |
| 5B19 | Tooltip system | Hover tooltips for abilities |
| 5B20 | Context menus | Right-click unit menus |
| 5B21 | Selection circles | Ground decals for selected units |
| 5B22 | Health bars | 3D floating health bars |
| 5B23 | Damage numbers | Floating combat text |
| 5B24 | Buff icons | Display aura icons on units |
| 5B25 | Vertical slice demo | F5 toggle working demo |

**Total:** 25 issues

**Acceptance Criteria:**
- ✓ WC3-style camera fully functional
- ✓ WoW-style camera fully functional
- ✓ F5 key toggles between views smoothly
- ✓ UI adapts to active view mode
- ✓ Selection/targeting works in both modes
- ✓ Minimap shows correct info for each mode

---

### Phase 5C: Client Custom Protocol Extensions

**Scope:** Add custom protocol for WC3-enhanced AC servers

**New Issues:**

| Issue | Title | Description |
|-------|-------|-------------|
| 5C01 | Custom protocol design | Define packet structures |
| 5C02 | Protocol negotiation | Detect if server supports custom protocol |
| 5C03 | WC3 metadata packets | Send/receive custom ability data |
| 5C04 | Custom UI data packets | Additional UI info (resource types, etc.) |
| 5C05 | Extended entity data | WC3-specific unit properties |
| 5C06 | Trigger event packets | Server → client trigger notifications |
| 5C07 | Custom map info | Map-specific data (game mode, rules) |
| 5C08 | Fallback to vanilla | Gracefully degrade if no custom protocol |
| 5C09 | Protocol versioning | Handle multiple protocol versions |
| 5C10 | Integration test | Connect to WC3-enhanced server |

**Total:** 10 issues

**Acceptance Criteria:**
- ✓ Can detect custom protocol support at login
- ✓ Falls back to vanilla mode if not supported
- ✓ Receives WC3 metadata when available
- ✓ UI shows enhanced info (custom tooltips, etc.)
- ✓ Works with both vanilla and custom servers

---

### Phase 6: Data Conversion - WC3 → AC (NEW)

**Scope:** Convert WC3 map data to AzerothCore-compatible formats

**New Issues:**

| Issue | Title | Description |
|-------|-------|-------------|
| 601 | Terrain converter | w3e → .adt/.wdt files |
| 602 | Unit converter | doo → creature_template SQL |
| 603 | Item converter | w3t → item_template SQL |
| 604 | Doodad converter | doo → gameobject_template SQL |
| 605 | Trigger converter | wtg → Eluna scripts |
| 606 | Coordinate mapper | WC3 ↔ WoW coordinate conversion |
| 607 | Texture mapper | WC3 textures → WoW texture IDs |
| 608 | Sound mapper | WC3 sounds → WoW sound IDs |
| 609 | String table exporter | wts → DBC strings |
| 610 | Conversion CLI tool | Automated map → AC conversion |
| 611 | SQL schema generator | Create AC database tables |
| 612 | Deployment packager | Package converted data for AC |

**Total:** 12 issues

**Acceptance Criteria:**
- ✓ Can convert simple WC3 map to AC format
- ✓ Terrain displays correctly in WoW client
- ✓ Units spawn at correct positions
- ✓ Items have correct stats
- ✓ Basic triggers work (via Eluna)
- ✓ Can deploy to AC server with one command

---

### Phase 7: Custom Ability Bridge (NEW)

**Scope:** Handle WC3 custom abilities that AC doesn't natively support

**New Issues:**

| Issue | Title | Description |
|-------|-------|-------------|
| 701 | Ability parser | Parse war3map.w3a (object editor) |
| 702 | Ability classifier | Classify abilities by complexity |
| 703 | Eluna script generator | Generate Lua scripts from ability data |
| 704 | Ability templates | Standard templates (chain, AoE, buff, etc.) |
| 705 | Spell ID allocator | Assign AC spell IDs to custom abilities |
| 706 | Ability testing framework | Unit tests for generated scripts |
| 707 | Performance profiler | Identify slow abilities |
| 708 | C++ migration tool | Port Eluna → C++ for hot paths (optional) |

**Total:** 8 issues

**Acceptance Criteria:**
- ✓ Can parse WC3 custom abilities
- ✓ Generates working Eluna scripts
- ✓ Chain Lightning works correctly (5 bounces, damage decay)
- ✓ Custom hero abilities functional
- ✓ Performance acceptable (<10ms per cast)
- ✓ Can identify abilities needing C++ optimization

---

### Phases 8-11: Renumbered (No Scope Changes)

**Phase 8: Integration - Map Loading** (was Phase 6)
- No scope changes
- Issues renumbered from 6xx → 8xx

**Phase 9: Gameplay - Core Mechanics** (was Phase 7)
- Dual WC3/WoW mode support (as originally designed)
- Death system (already complete)
- Profession system (WC3 + WoW modes)
- Issues renumbered from 7xx → 9xx

**Phase 10: Optimization - Performance** (was Phase 8)
- No scope changes
- Issues renumbered from 8xx → 10xx

**Phase 11: Polish - User Experience** (was Phase 9)
- No scope changes
- Issues renumbered from 9xx → 11xx

---

## Migration Plan

### Step 1: Audit Phase 4 (IMMEDIATE)

**Tasks:**
1. Read all 34 Phase 4 issue files
2. Mark each issue as:
   - **KEEP** - Still relevant for client-side logic
   - **MODIFY** - Needs scope change (server → client focus)
   - **DEPRECATE** - Redundant (AC handles this)
3. Create migration document: `issues/phase-4-audit.md`

**Deliverable:** List of which issues to keep/modify/deprecate

---

### Step 2: Create New Issue Files (WEEK 1)

**Phase 5A Issues (20):**
```bash
# Use issue template
for i in {01..20}; do
    cp issues/templates/implementation-issue.md issues/5A${i}-{title}.md
    # Fill in details from Phase 5 split
done
```

**Phase 5B Issues (25):**
```bash
for i in {01..25}; do
    cp issues/templates/implementation-issue.md issues/5B${i}-{title}.md
done
```

**Phase 5C Issues (10):**
```bash
for i in {01..10}; do
    cp issues/templates/implementation-issue.md issues/5C${i}-{title}.md
done
```

**Phase 6 Issues (12):**
```bash
for i in {01..12}; do
    cp issues/templates/implementation-issue.md issues/6${i}-{title}.md
done
```

**Phase 7 Issues (8):**
```bash
for i in {01..08}; do
    cp issues/templates/implementation-issue.md issues/7${i}-{title}.md
done
```

**Deliverable:** 75 new issue files created

---

### Step 3: Deprecate Phase 4 Issues (WEEK 1)

**For each deprecated Phase 4 issue:**

1. Add deprecation notice at top of file:
```markdown
**DEPRECATED:** This issue is no longer relevant.
**Reason:** AzerothCore handles this functionality.
**Date:** 2026-01-07
**Replacement:** See AzerothCore documentation at [link]

---

[Original issue content below]
```

2. Move to `issues/deprecated/phase-4/`
3. Update `issues/progress.md` to reflect deprecation

**Deliverable:** ~19 issues deprecated and moved

---

### Step 4: Renumber Phase 6-9 → 8-11 (WEEK 2)

**Automated renaming script:**

```bash
#!/bin/bash
# renumber_phases.sh

# Backup first
cp -r issues issues.backup.$(date +%Y%m%d)

# Renumber files
for file in issues/6*.md; do
    new_file=$(echo "$file" | sed 's/\/6/\/8/')
    git mv "$file" "$new_file"
done

for file in issues/7*.md; do
    new_file=$(echo "$file" | sed 's/\/7/\/9/')
    git mv "$file" "$new_file"
done

for file in issues/8*.md; do
    new_file=$(echo "$file" | sed 's/\/8/\/10/')
    git mv "$file" "$new_file"
done

for file in issues/9*.md; do
    new_file=$(echo "$file" | sed 's/\/9/\/11/')
    git mv "$file" "$new_file"
done

# Update cross-references in all files
find issues -name "*.md" -exec sed -i 's/\(Issue \)6\([0-9]\)/\18\2/g' {} \;
find issues -name "*.md" -exec sed -i 's/\(Issue \)7\([0-9]\)/\19\2/g' {} \;
find issues -name "*.md" -exec sed -i 's/\(Issue \)8\([0-9]\)/\110\2/g' {} \;
find issues -name "*.md" -exec sed -i 's/\(Issue \)9\([0-9]\)/\111\2/g' {} \;
```

**Deliverable:** 32 issues renumbered (6xx → 8xx, 7xx → 9xx, etc.)

---

### Step 5: Update Documentation (WEEK 2)

**Files to update:**

1. **`docs/roadmap.md`**
   - Replace phase structure
   - Update issue counts
   - Add new phase descriptions

2. **`issues/progress.md`**
   - Update current phase status
   - Add new phases
   - Mark deprecated issues

3. **`docs/table-of-contents.md`**
   - Add new design documents
   - Update phase references

4. **`CLAUDE.md`**
   - Update phase summary
   - Add reference to new architecture docs

**Deliverable:** All docs updated with new structure

---

### Step 6: Git Commit (WEEK 2)

```bash
git add issues/ docs/
git commit -m "$(cat <<'EOF'
Reorganize phases for AzerothCore integration

Major architectural shift: world-edit-to-execute is a WC3 map data
pipeline and custom client for AzerothCore, not a standalone engine.

Changes:
- Phase 4: Reduced from 34 to 15 issues (deprecated server state logic)
- Phase 5: Split into 5A/5B/5C (client core, dual-view, custom protocol)
- Phase 6: NEW - Data Conversion Pipeline (WC3 → AC format)
- Phase 7: NEW - Custom Ability Bridge (Eluna script generation)
- Phase 6-9: Renumbered to 8-11

Created design documents:
- docs/azerothcore-integration-architecture.md
- docs/client-architecture.md
- docs/data-conversion-pipeline.md
- docs/custom-ability-bridge.md
- docs/phase-reorganization.md

Deprecated Phase 4 issues moved to issues/deprecated/phase-4/

See docs/phase-reorganization.md for full migration plan.

🤖 Generated with Claude Code
Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
EOF
)"
```

**Deliverable:** Clean git history with reorganization committed

---

## Impact Analysis

### Timeline Impact

**Original Timeline (estimated):**
- Phases 0-4: 4 months (✓ complete)
- Phases 5-9: 8 months (pending)
- **Total:** 12 months

**New Timeline (estimated):**
- Phases 0-4: 4 months (✓ complete, some deprecated)
- Phase 5A: 3 weeks (basic client)
- Phase 5B: 4 weeks (dual-view)
- Phase 5C: 2 weeks (custom protocol)
- Phase 6: 3 weeks (data conversion)
- Phase 7: 2 weeks (ability bridge)
- Phases 8-11: 6 months (integration, gameplay, optimization, polish)
- **Total:** ~10 months remaining

**Time Saved:** ~2 months (by using AC instead of building full engine)

---

### Codebase Impact

**Lines of Code (estimated):**

| Component | Original Plan | New Plan | Difference |
|-----------|---------------|----------|------------|
| Phase 4 Runtime | 8,000 LOC | 3,000 LOC | -5,000 (AC handles this) |
| Phase 5 Rendering | 12,000 LOC | 15,000 LOC | +3,000 (dual-view complexity) |
| Phase 6 Conversion | 0 LOC | 4,000 LOC | +4,000 (NEW) |
| Phase 7 Abilities | 0 LOC | 3,000 LOC | +3,000 (NEW) |
| **Total** | **20,000 LOC** | **25,000 LOC** | **+5,000** |

**Why more code?**
- Client complexity increased (dual protocol, dual view)
- Data conversion logic added
- Code generation systems (Eluna scripts, SQL)

**But:** We don't have to write:
- Server networking (~10,000 LOC)
- Combat system (~8,000 LOC)
- Database layer (~5,000 LOC)
- **Saved:** ~23,000 LOC

**Net Result:** ~18,000 LOC less to write (AC provides this)

---

### Maintenance Impact

**Original Plan:**
- Maintain standalone server
- Maintain client
- Maintain networking layer
- **Effort:** High (3 major systems)

**New Plan:**
- Maintain client only
- Maintain data conversion tools (code generation, mostly stable)
- Track AzerothCore updates (monthly merges if using fork)
- **Effort:** Medium (1 major system, 1 minor system, 1 dependency)

**Improvement:** ~40% less maintenance burden

---

### Testing Impact

**Original Plan:**
- Test standalone server (game logic, networking, database)
- Test client (rendering, input, UI)
- Test client-server integration
- **Test Matrix:** 3 systems × 3 environments = 9 test scenarios

**New Plan:**
- Test client only (rendering, input, UI, protocol)
- Test data conversion (WC3 → AC correctness)
- Test on AzerothCore (integration)
- **Test Matrix:** 2 systems × 2 environments = 4 test scenarios

**Improvement:** ~50% less testing surface area (AC is already tested)

---

## Risks and Mitigations

### Risk 1: AzerothCore API Changes

**Risk:** AC updates break our integration

**Likelihood:** Medium (monthly AC updates)

**Impact:** Medium (1-2 days to fix per update)

**Mitigation:**
- Pin AC version for each release
- Test against AC master branch weekly
- Maintain AC compatibility layer (abstract AC API calls)
- Fork AC only if necessary (keeps control)

---

### Risk 2: Eluna Performance Insufficient

**Risk:** Lua overhead makes abilities lag

**Likelihood:** Low (Eluna proven in production)

**Impact:** High (would need C++ fork, 4-6 week delay)

**Mitigation:**
- Profile abilities early (Phase 7 includes profiler)
- Start with Eluna, migrate hot paths to C++ only if needed
- Set performance budget (<10ms per ability cast)
- Use C++ for <10% of abilities if necessary (hybrid approach)

---

### Risk 3: WC3 → AC Conversion Lossy

**Risk:** Some WC3 mechanics impossible to represent in AC

**Likelihood:** Medium (WC3 has unique systems)

**Impact:** Medium (some maps may not convert perfectly)

**Mitigation:**
- Document conversion limitations upfront
- Provide "conversion compatibility score" for maps
- Offer manual workarounds for edge cases
- Build custom systems for most-requested features

---

### Risk 4: Custom Protocol Rejected by Players

**Risk:** Players don't want custom client, prefer vanilla

**Likelihood:** Low (optional, falls back to vanilla)

**Impact:** Low (Phase 5C is optional)

**Mitigation:**
- Make custom protocol optional (Phase 5C)
- Ensure vanilla mode fully functional (Phase 5A)
- Market as "enhanced experience" not "required"
- Support both vanilla WoW client AND custom client

---

### Risk 5: Phase Renumbering Breaks References

**Risk:** Cross-references in docs/issues break after renumbering

**Likelihood:** High (manual renumbering error-prone)

**Impact:** Low (easily fixable with grep)

**Mitigation:**
- Use automated renumbering script (see Step 4)
- Git grep to find broken references before commit
- Test issue-splitter tool after renumbering
- Keep backup before renumbering (issues.backup.*)

---

## Success Criteria

The phase reorganization is successful when:

1. ✅ All deprecated Phase 4 issues moved to `issues/deprecated/`
2. ✅ New Phase 5A/5B/5C/6/7 issues created (75 files)
3. ✅ Old Phase 6-9 renumbered to 8-11 (32 files)
4. ✅ Documentation updated (roadmap, progress, ToC)
5. ✅ Git commit clean with clear message
6. ✅ Issue-splitter tool still works after renumbering
7. ✅ No broken cross-references in issues/docs
8. ✅ New phase structure matches AC integration architecture

---

## Appendices

### Appendix A: Phase 4 Audit Template

```markdown
# Phase 4 Issue Audit

**Issue:** {ID} - {Title}
**Status:** {KEEP | MODIFY | DEPRECATE}

## Original Scope
{What the issue originally intended}

## Relevance to AC Integration
{Why this is/isn't needed with AzerothCore}

## Recommendation
- [ ] **KEEP** - Still needed for client-side logic
- [ ] **MODIFY** - Change scope to focus on {what}
- [ ] **DEPRECATE** - AzerothCore handles this

## Notes
{Additional context}
```

---

### Appendix B: Issue Naming Convention Updates

**Old Convention:**
```
{PHASE}{ID}-{description}.md
Example: 501-protocol-implementation.md
```

**New Convention (for split phases):**
```
{PHASE}{SUBPHASE}{ID}-{description}.md
Example: 5A01-auth-protocol.md
         5B15-resource-bars.md
         5C03-metadata-packets.md
```

**Rationale:**
- Alphabetic subphase keeps issues grouped (5A*, 5B*, 5C*)
- Sequential ID within subphase (01-20)
- Clear hierarchy (5A = Phase 5, Subphase A)

---

### Appendix C: Cross-Reference Update Script

```bash
#!/bin/bash
# update_references.sh
# Updates cross-references after phase renumbering

# Update Issue references (Issue 6xx → Issue 8xx)
find issues docs -name "*.md" -type f -exec sed -i \
  's/\(Issue \)6\([0-9][0-9]\)/\18\2/g' {} \;

# Update file references (issues/6xx → issues/8xx)
find issues docs -name "*.md" -type f -exec sed -i \
  's|\(issues/\)6\([0-9][0-9]\)|\18\2|g' {} \;

# Update Phase mentions (Phase 6 → Phase 8, but not "Phase 6A")
find issues docs -name "*.md" -type f -exec sed -i \
  's/Phase 6\([^A-C0-9]\)/Phase 8\1/g' {} \;
find issues docs -name "*.md" -type f -exec sed -i \
  's/Phase 7\([^A-C0-9]\)/Phase 9\1/g' {} \;
find issues docs -name "*.md" -type f -exec sed -i \
  's/Phase 8\([^A-C0-9]\)/Phase 10\1/g' {} \;
find issues docs -name "*.md" -type f -exec sed -i \
  's/Phase 9\([^A-C0-9]\)/Phase 11\1/g' {} \;

echo "Cross-references updated. Run 'git diff' to review changes."
```

---

### Appendix D: New Phase Progress Template

```markdown
# Phase {N} Progress: {Title}

**Status:** {Not Started | In Progress | Complete}
**Started:** {Date}
**Completed:** {Date or TBD}

---

## Overview

{Brief description of phase goals}

---

## Issues

| Issue | Title | Status | Dependencies |
|-------|-------|--------|--------------|
| {ID}  | {Name}| {Status}| {List}      |

---

## Acceptance Criteria

- [ ] {Criterion 1}
- [ ] {Criterion 2}
- [ ] {Criterion N}

---

## Notes

{Additional context, blockers, decisions}
```

---

## Related Documents

- `docs/azerothcore-integration-architecture.md` - Overall AC integration
- `docs/client-architecture.md` - Client design (Phase 5 split)
- `docs/data-conversion-pipeline.md` - Phase 6 scope
- `docs/custom-ability-bridge.md` - Phase 7 scope
- `docs/roadmap.md` - Updated phase structure (to be modified)
- `issues/progress.md` - Current progress tracking (to be modified)

---

## Revision History

| Date | Change | Author |
|------|--------|--------|
| 2026-01-07 | Initial phase reorganization proposal | Claude |
