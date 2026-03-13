# Issue 701d: BSP Occlusion Implementation

## Status
- Phase: 7
- Priority: High
- Status: Open
- Dependencies: 701c-bsp-research-prototyping
- Parent Issue: 701-dynamic-occlusion-system

## Overview

Implement the BSP occlusion strategy determined by Issue 701c's research findings.

**IMPORTANT**: This issue cannot be fully defined until Issue 701c completes. The implementation approach depends entirely on what the research reveals is possible.

## Current Behavior

No BSP occlusion exists. BSP geometry (walls, ceilings) blocks the player's view of units.

## Intended Behavior

Based on 701c findings, implement the best available solution for BSP visibility. This could range from:
- Full per-surface control (best case)
- Zone-level control (acceptable)
- Workaround approaches (limited)
- No BSP control with alternative solutions (fallback)

## Pre-Implementation Checklist

Before implementing, confirm:

- [ ] Issue 701c is complete
- [ ] Research findings are documented
- [ ] Recommendation is clear
- [ ] Prototype from 701c is available
- [ ] Limitations are understood

## Implementation Branches

### Branch A: Full BSP Surface Control

If 701c finds a way to control individual BSP surfaces:

1. Integrate surface identification with trace system
2. Implement per-surface visibility toggle
3. Create material/transparency system for BSP
4. Handle surface restoration
5. Optimize for performance

### Branch B: Zone-Based Control

If BSP can only be controlled at zone level:

1. Map zone boundaries to camera positions
2. Implement zone visibility toggling
3. Create "important" zone protection (don't hide gameplay zones)
4. Handle zone transition smoothing
5. Document limitations per-map

### Branch C: Workaround Implementation

If direct BSP control is impossible, implement workarounds:

1. **Projector Approach**
   - Create transparency projectors
   - Position at detected BSP intersections
   - Manage projector lifecycle

2. **Unit Overlay Approach**
   - Modify unit rendering to draw on top
   - Implement silhouette rendering
   - Handle depth sorting

3. **Camera Adjustment**
   - Auto-adjust camera angle to minimize occlusion
   - Implement dynamic camera height
   - Create "peek" modes

### Branch D: Fallback - No BSP Handling

If BSP cannot be handled:

1. Document the limitation clearly
2. Create map compatibility guide
3. Implement enhanced minimap for occluded units
4. Add unit indicators (outlines, pings)
5. Adjust game design around limitation

## Suggested Implementation Steps

(To be refined based on 701c findings)

### Step 1: Review 701c Prototype
- Understand working prototype from research
- Identify production requirements
- Note edge cases and limitations

### Step 2: Production Implementation
- Convert prototype to production code
- Add error handling
- Implement configuration options
- Create debug modes

### Step 3: Integration with Actor System
- Ensure BSP and actor occlusion work together
- Handle overlapping cases
- Maintain consistent visual style

### Step 4: Edge Case Handling
- Map-specific issues
- Performance on complex geometry
- Multiplayer synchronization
- Save/load state (if relevant)

### Step 5: Testing and Validation
- Test on stock maps (see 701c survey)
- Performance profiling
- Visual quality assessment
- Gameplay impact testing

## Map Compatibility Matrix

Based on 701c findings, maintain compatibility information:

| Map | BSP Occlusion Level | Notes |
|-----|---------------------|-------|
| DM-Rankin | | |
| DM-Deck17 | | |
| ONS-Torlan | | |
| (etc.) | | |

## Related Documents
- docs/006-rendering-system-technical.md
- issues/701c-bsp-research-prototyping.md (must complete first)
- issues/701b-actor-occlusion-handling.md
- issues/701-dynamic-occlusion-system.md (parent)

## Acceptance Criteria

(To be finalized after 701c completes)

Base criteria:
- [ ] Implements recommendation from 701c
- [ ] Integrates with existing occlusion system
- [ ] Works on at least 5 stock maps
- [ ] Performance acceptable
- [ ] No crashes or instability
- [ ] Documented limitations

## Notes

This issue is intentionally under-specified pending 701c research.

The approach will be dramatically different depending on whether BSP can be:
- Controlled directly
- Controlled indirectly
- Not controlled at all

Be prepared to adapt the implementation to match reality.

If 701c determines BSP occlusion is impossible, this issue may be replaced with fallback implementation instead.
