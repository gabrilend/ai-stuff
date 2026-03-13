# Issue 701: Dynamic Occlusion System (Parent Issue)

## Status
- Phase: 7
- Priority: Critical
- Status: Open
- Dependencies: Phase 2 (Camera System), Phase 6 (AI Behavior)

## Overview

This is the parent issue for the Dynamic Occlusion Rendering System - the most technically challenging feature of the entire project.

The goal is to make map geometry transparent or hidden when it obstructs the player's top-down view of their units. This must work on existing UT2004 maps without requiring map modifications.

## Why This Is Difficult

1. **Engine Limitations**: Unreal Engine 2 has limited runtime rendering control
2. **BSP Geometry**: Core level geometry cannot be easily modified at runtime
3. **Performance**: Many traces per frame required for accurate detection
4. **Multiplayer**: Each player needs separate occlusion calculations

## Sub-Issues

This issue is broken into focused sub-issues:

- **701a**: Occlusion Detection Framework - Ray tracing and geometry identification
- **701b**: Actor Occlusion Handling - StaticMeshes, Movers, Decorations
- **701c**: BSP Research and Prototyping - Investigate BSP modification possibilities
- **701d**: BSP Occlusion Implementation - Implement chosen BSP strategy
- **701e**: Performance Optimization - Caching, LOD, spatial partitioning
- **701f**: Visual Polish - Transitions, edge cases, consistency

## Technical Documentation

See `docs/006-rendering-system-technical.md` for comprehensive technical analysis including:
- Geometry type analysis
- Detection algorithms
- Rendering modification strategies
- BSP problem analysis
- Performance optimization techniques
- Multiplayer considerations
- Fallback strategies

## Current Behavior

No occlusion system exists. From a top-down view, map geometry (roofs, ceilings, tall walls) completely blocks the player's view of units on the ground.

## Intended Behavior

When geometry would occlude a unit or AI waypoint from the player's camera:
1. The system detects which geometry is occluding
2. The geometry is made transparent, hidden, or otherwise modified
3. The player can see their units through the geometry
4. When the camera moves, occlusion updates dynamically
5. Performance remains acceptable (30+ FPS)

## Critical Path

```
701a (Detection) ──► 701b (Actors) ──► 701e (Performance)
                                              │
701a (Detection) ──► 701c (BSP Research) ──► 701d (BSP Impl) ──► 701e ──► 701f (Polish)
```

Issues 701c and 701b can run in parallel after 701a.
Issue 701e should be applied to both actor and BSP systems.
Issue 701f finalizes everything.

## Risk Assessment

### High Risk
- BSP geometry may not be modifiable at runtime
- Performance may be unacceptable with full detection

### Medium Risk
- Material transparency may not look acceptable
- Multiplayer sync may have issues

### Mitigation
- Fallback strategies documented in technical docs
- Early prototyping in 701c to identify blockers
- Performance focus throughout, not just at end

## Acceptance Criteria (Phase 7 Complete)

- [ ] All sub-issues (701a-701f) completed
- [ ] Units visible through occluding geometry
- [ ] Works on at least 3 stock UT2004 maps
- [ ] Performance acceptable (30+ FPS with 20+ units)
- [ ] Multiplayer occlusion works independently per player
- [ ] Smooth visual transitions
- [ ] Phase 7 demo showcases occlusion on complex map

## Related Documents

- docs/002-rendering-system.md (overview)
- docs/006-rendering-system-technical.md (deep dive)
- docs/005-roadmap.md (Phase 7)
- notes/vision (original concept)

## Notes

This system is essential to the game's playability. Without it, the top-down perspective is unusable on most maps.

If BSP occlusion proves impossible, fallback strategies exist (documented in technical docs) but they compromise the original vision of supporting any UT2004 map.

Early research in Issue 701c is critical to determine feasibility before investing heavily in implementation.
