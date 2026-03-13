# Phase 7 Progress: Dynamic Occlusion System

## Phase Overview

Implement raycasting-based geometry occlusion to ensure units remain visible when viewed from above, even when map geometry would normally block the view.

**Complexity Rating**: HIGH
**Risk Level**: MEDIUM-HIGH (BSP handling uncertain)

## Phase Goals

- Create occlusion detection framework using cone-based raycasting
- Implement actor-based geometry occlusion (StaticMeshes, Movers)
- Research and implement best available BSP handling
- Optimize for performance (<2ms per update)
- Support multiplayer with per-player occlusion
- Create smooth visual transitions

## Critical Dependencies

- Phase 2: Camera System (must be working)
- Phase 6: AI Behavior (units must exist to occlude for)

## Issue Tracking

### 701: Dynamic Occlusion System (Parent Issue)
- **Status**: Open
- **Priority**: Critical
- **Description**: Parent issue for entire occlusion system
- **Notes**: See sub-issues below for detailed tracking

### 701a: Occlusion Detection Framework
- **Status**: Open
- **Priority**: Critical
- **Progress**: 0%
- **Dependencies**: Phase 2 complete
- **Description**: Core ray tracing system, waypoint filtering, geometry identification
- **Blockers**: None (can start when Phase 6 complete)
- **Estimated Complexity**: Medium

### 701b: Actor Occlusion Handling
- **Status**: Open
- **Priority**: High
- **Progress**: 0%
- **Dependencies**: Issue 701a
- **Description**: Hide/transparency for StaticMeshes, Movers, Decorations
- **Blockers**: Waiting for 701a
- **Estimated Complexity**: Medium

### 701c: BSP Research and Prototyping
- **Status**: Open
- **Priority**: Critical (determines feasibility)
- **Progress**: 0%
- **Dependencies**: Issue 701a
- **Description**: Research whether BSP can be modified at runtime
- **Blockers**: Waiting for 701a
- **Estimated Complexity**: Unknown (research phase)
- **Risk**: May determine full occlusion is impossible

### 701d: BSP Occlusion Implementation
- **Status**: Open
- **Priority**: High
- **Progress**: 0%
- **Dependencies**: Issue 701c
- **Description**: Implement BSP handling based on research findings
- **Blockers**: Waiting for 701c research completion
- **Estimated Complexity**: Unknown (depends on 701c)

### 701e: Performance Optimization
- **Status**: Open
- **Priority**: High
- **Progress**: 0%
- **Dependencies**: Issues 701b, 701d
- **Description**: Caching, LOD, spatial partitioning, profiling
- **Blockers**: Waiting for 701b and 701d
- **Estimated Complexity**: Medium-High

### 701f: Visual Polish
- **Status**: Open
- **Priority**: Medium
- **Progress**: 0%
- **Dependencies**: Issue 701e
- **Description**: Smooth transitions, edge cases, user options
- **Blockers**: Waiting for 701e
- **Estimated Complexity**: Medium

## Progress Metrics

**Overall Phase Progress**: 0/7 issues completed (0%)
- Parent Issue: 0% (701)
- Sub-Issues: 0/6 completed (701a-701f)

**Critical Path**:
1. Issue 701a (Detection Framework)
2. Issue 701c (BSP Research) ← CRITICAL DECISION POINT
3. Issue 701d (BSP Implementation)
4. Issue 701e (Performance)
5. Issue 701f (Polish)

**Parallel Track**:
- Issues 701b and 701c can run in parallel after 701a

## Risk Mitigation

### Primary Risk: BSP Occlusion Impossible

If Issue 701c determines BSP cannot be handled:

**Fallback A**: Accept BSP limitations
- Only handle actor occlusion
- Camera angle adjustments to minimize BSP occlusion
- Map design guidelines for best experience

**Fallback B**: Silhouette rendering
- Don't modify geometry
- Draw unit silhouettes through occluders
- Requires render-to-texture or canvas work

**Fallback C**: Enhanced minimap
- Show occluded unit positions on minimap
- Add unit indicators/pings

### Secondary Risk: Performance Unacceptable

If occlusion causes <30 FPS:
- Quality settings (user choice)
- Reduce trace frequency
- Reduce waypoint count
- Accept lower detection accuracy

## Technical Documentation

- `docs/002-rendering-system.md` - Overview
- `docs/006-rendering-system-technical.md` - Comprehensive technical analysis
- Individual issue files contain implementation details

## Completion Criteria

Phase 7 is complete when:
- [ ] All 7 issues closed (701, 701a-701f)
- [ ] Units visible through occluding geometry (actors at minimum)
- [ ] BSP handling implemented (extent based on research)
- [ ] Performance targets met (<2ms, >30 FPS)
- [ ] Multiplayer occlusion works
- [ ] Works on 5+ stock maps
- [ ] Phase 7 demo showcases system
- [ ] Fallback strategies documented (if needed)

## Next Steps

When Phase 6 completes:

1. Begin Issue 701a: Create SR_OcclusionManager
   - Implement waypoint filtering
   - Implement cone-based tracing
   - Add debug visualization

2. Once 701a provides detection, start 701b and 701c in parallel
   - 701b: Actor transparency/hiding
   - 701c: BSP research

3. 701c findings determine 701d approach
   - Schedule checkpoint meeting after 701c

## Lessons Learned

(To be filled in as phase progresses)

## Related Documents

- docs/005-roadmap.md - Phase 7 section
- docs/002-rendering-system.md - Overview
- docs/006-rendering-system-technical.md - Technical deep dive
- notes/vision - Original concept
