# Issue 701c: BSP Research and Prototyping

## Status
- Phase: 7
- Priority: Critical
- Status: Open
- Dependencies: 701a-occlusion-detection-framework
- Parent Issue: 701-dynamic-occlusion-system

## Overview

This is a RESEARCH issue. The goal is to investigate whether BSP geometry (walls, ceilings, floors built into maps) can be dynamically hidden or made transparent at runtime in UT2004.

BSP is the most challenging geometry type because:
1. It's compiled at map build time
2. It's not represented as individual actors
3. Materials are shared across surfaces
4. Visibility is controlled by zones, not per-surface

This issue will determine whether full BSP occlusion is possible, partially possible, or impossible. The findings will directly inform Issue 701d's implementation approach.

## Current Behavior

BSP geometry cannot be selectively hidden. Traces against BSP return `Level` as the hit actor, not specific geometry. There is no known way to hide individual BSP surfaces at runtime.

## Research Goals

1. **Determine what's possible** with BSP visibility in UT2004
2. **Document all attempted approaches** with results
3. **Identify the best viable strategy** for BSP occlusion
4. **Prototype the most promising approach** to prove feasibility
5. **Provide clear recommendation** for Issue 701d

## Research Tasks

### Task 1: Zone Visibility Investigation

**Question**: Can zone visibility be controlled at runtime?

**Approach**:
1. Create test map with multiple zones
2. Find zone actor references in UnrealScript
3. Test `bNoVisibility`, `bSoftKillZ`, zone properties
4. Document effects on geometry visibility

**Test Code**:
```unrealscript
// {{{ function TestZoneVisibility
function TestZoneVisibility()
{
    local ZoneInfo ZI;

    foreach AllActors(class'ZoneInfo', ZI)
    {
        Log("Zone:" @ ZI.Name @ "Location:" @ ZI.Location);

        // Try toggling visibility
        ZI.bNoVisibility = !ZI.bNoVisibility;

        // Document result
    }
}
// }}}
```

**Expected Outcome**: Zones can be hidden but it's all-or-nothing per zone, not selective.

**Actual Outcome**: [To be documented during research]

---

### Task 2: Surface/Texture Identification

**Question**: Can we identify specific BSP surfaces from trace hits?

**Approach**:
1. Use `TraceTexture()` if available
2. Check for surface flags in trace results
3. Investigate `HitMaterial` functionality
4. Test on various BSP surface types

**Test Code**:
```unrealscript
// {{{ function TestBSPSurfaceDetection
function TestBSPSurfaceDetection()
{
    local Vector HitLoc, HitNorm;
    local Actor HitActor;
    local Material HitMat;
    local name HitTextureName;

    // Trace downward from camera
    HitActor = Trace(HitLoc, HitNorm, Location - vect(0,0,1000), Location, true);

    if (HitActor == Level)
    {
        Log("Hit BSP at:" @ HitLoc);
        Log("Normal:" @ HitNorm);

        // Try to get texture/material info
        // (method depends on engine version)
    }
}
// }}}
```

**Expected Outcome**: Can identify surface texture but cannot modify it.

**Actual Outcome**: [To be documented during research]

---

### Task 3: BSP Material Modification

**Question**: Can BSP materials be modified at runtime?

**Approach**:
1. Find how BSP materials are stored (LevelInfo, elsewhere)
2. Attempt to access material array
3. Try modifying material properties
4. Test if changes affect rendering

**Warning**: This is unlikely to work and may cause instability.

**Expected Outcome**: BSP materials are baked and cannot be modified.

**Actual Outcome**: [To be documented during research]

---

### Task 4: Mover as BSP Proxy

**Question**: Can movers serve as stand-ins for BSP ceiling geometry?

**Approach**:
1. Create test map with mover-based ceiling
2. Test if movers can be hidden/transparent
3. Evaluate visual quality
4. Document performance implications

**Expected Outcome**: Movers can be hidden but require map redesign.

**Actual Outcome**: [To be documented during research]

---

### Task 5: Camera Clipping Exploration

**Question**: Can we use camera clipping to hide BSP ceilings?

**Approach**:
1. Test modifying `FovAngle`, clip planes
2. Try `ClipPlane` properties
3. Investigate custom camera views
4. Document visual artifacts

**Test Code**:
```unrealscript
// {{{ function TestCameraClipping
function TestCameraClipping()
{
    local PlayerController PC;

    PC = PlayerController(Owner);

    // Try various approaches
    PC.FOVAngle = 90;
    // Test clip plane if available
}
// }}}
```

**Expected Outcome**: Camera clipping affects ALL geometry, not selective.

**Actual Outcome**: [To be documented during research]

---

### Task 6: Native Code Investigation

**Question**: What would native code modification enable?

**Approach**:
1. Research UT2004 source code availability
2. Identify relevant rendering code sections
3. Document what native access would allow
4. Assess feasibility of native modifications

**Expected Outcome**: Native code could enable per-surface visibility but requires significant engine work.

**Actual Outcome**: [To be documented during research]

---

### Task 7: Alternative Approaches

**Question**: What workarounds exist for BSP limitations?

**Approaches to Test**:

1. **Projector-Based Masking**
   - Project dark/transparent texture on ceilings
   - Test if this creates pseudo-transparency effect

2. **Overlay Rendering**
   - Render units in a separate pass
   - Draw units over everything
   - Test if UnrealScript can control render order

3. **Skybox Exploitation**
   - If camera is in skybox, different rendering rules may apply
   - Test skybox view vs normal view

4. **AntiPortal Abuse**
   - AntiPortals add occlusion; test if inverse is possible
   - Spawn/manipulate antiportals dynamically

5. **Fog/Volume Effects**
   - Heavy fog at ceiling level
   - May obscure ceiling naturally

---

### Task 8: Map Survey

**Question**: How often does BSP occlusion occur on stock maps?

**Approach**:
1. Test camera position on 10+ stock maps
2. Document which maps have severe BSP occlusion
3. Identify map characteristics that help/hurt
4. Create recommendation for map compatibility

**Maps to Test**:
- DM-Rankin
- DM-Deck17
- DM-Morpheus3
- DM-1on1-Roughinery
- DM-Compressed
- ONS-Torlan
- ONS-Primeval
- CTF-FaceClassic
- CTF-Citadel
- BR-Colossus

---

## Documentation Requirements

For each research task, document:

1. **Approach Taken**: What exactly was tried
2. **Code Used**: Any test code (even if it didn't work)
3. **Results**: What happened
4. **Analysis**: Why it worked or didn't
5. **Viability**: Could this be used in production?
6. **Performance**: Any performance implications
7. **Stability**: Did it cause crashes or issues?

## Prototype Deliverable

Based on research findings, create a minimal prototype demonstrating the most viable BSP handling approach.

The prototype should:
- Work on at least one stock map
- Be toggleable for testing
- Have debug visualization
- Document limitations

## Final Recommendation

After completing research, provide a clear recommendation for Issue 701d:

### Option A: Full BSP Occlusion
If a viable method is found to hide/fade individual BSP surfaces.

### Option B: Partial BSP Occlusion
If BSP can be handled at zone level or with limitations.

### Option C: No BSP Occlusion
If BSP cannot be handled, recommend fallback strategies:
- Silhouette rendering for units
- Map design guidelines
- Camera angle adjustments
- Accept occlusion as gameplay element

### Option D: Native Code Required
If BSP occlusion requires engine modifications.

## Related Documents
- docs/006-rendering-system-technical.md (BSP Problem section)
- issues/701a-occlusion-detection-framework.md
- issues/701d-bsp-occlusion-implementation.md
- issues/701-dynamic-occlusion-system.md (parent)

## Technical References

### UnrealScript Classes to Investigate
- LevelInfo
- ZoneInfo
- PhysicsVolume
- AntiPortalActor
- Projector
- Camera / PlayerCamera

### Engine Source Files (if accessible)
- UnRender.cpp - BSP rendering
- UnBsp.cpp - BSP structures
- UnLevel.cpp - Level loading
- UnCamera.cpp - View rendering

## Acceptance Criteria

- [ ] All 8 research tasks completed
- [ ] Findings documented for each task
- [ ] Prototype created for most viable approach
- [ ] Clear recommendation provided for 701d
- [ ] Map compatibility survey completed
- [ ] Documentation suitable for future reference
- [ ] No permanent changes to game installation

## Notes

This is pure research. Do not implement production code here.

Document negative results as thoroughly as positive ones - knowing what DOESN'T work is valuable.

Take time on this issue. A thorough investigation now prevents wasted effort in 701d.

If BSP occlusion proves impossible, this is not a failure - it informs the project's direction and allows us to focus on viable alternatives.

## Time Box

Suggest 2-3 focused sessions for this research. Don't spend unlimited time if approaches aren't working.

After initial investigation, reassess whether to continue or move to fallback strategies.
