# Dynamic Occlusion System - Technical Deep Dive

## Overview

This document provides in-depth technical analysis of the dynamic occlusion rendering system. This is anticipated to be the most challenging component of the entire project due to the limitations of Unreal Engine 2 and the complexity of real-time geometry occlusion.

---

## The Core Problem

### What We Need To Achieve

When the player views the game from a top-down perspective, map geometry (walls, ceilings, buildings, decorations) will obstruct their view of units on the ground. We need to:

1. **Detect** which geometry is between the camera and the units
2. **Modify** that geometry's rendering to make units visible
3. **Restore** geometry when it no longer occludes
4. **Perform** all of this in real-time with acceptable performance

### Why This Is Difficult

1. **Engine Limitations**: Unreal Engine 2 (UT2004) predates modern shader-based rendering. It has limited runtime material modification capabilities.

2. **Geometry Types**: UT2004 maps contain multiple geometry types that must be handled differently:
   - BSP (Binary Space Partitioning) geometry - the core level structure
   - StaticMeshes - prefabricated 3D objects
   - Movers - doors, elevators, platforms
   - Decorations - smaller mesh objects
   - Terrain - outdoor heightmapped surfaces
   - Emitters/Projectors - visual effects

3. **No Stencil Buffer Access**: Modern occlusion techniques often use stencil buffers, which aren't easily accessible in UE2.

4. **Limited UnrealScript Rendering Control**: UnrealScript can manipulate actors but has limited control over BSP rendering.

---

## Geometry Types and Handling Strategies

### BSP Geometry

**What it is**: The compiled level geometry created in UnrealEd. Includes walls, floors, ceilings, and static architecture.

**Challenge**: BSP is baked at compile time. It cannot be dynamically modified at runtime in the traditional sense.

**Possible Approaches**:

1. **Zone-Based Visibility**
   - UT2004 uses zones for visibility culling
   - Zones can be made invisible via `bNoVisibility` flag
   - Problem: Zone boundaries are fixed at map compile time
   - Problem: Hiding a zone hides everything in it, including units

2. **AntiPortal Volumes**
   - AntiPortals occlude geometry behind them
   - Can be spawned/manipulated at runtime
   - Problem: They ADD occlusion, not remove it
   - Potential: Inverse usage might be possible

3. **Overlay/Projector Masking**
   - Project a "visibility" texture over occluding geometry
   - Make the projected area appear transparent
   - Problem: Projectors affect surfaces, not visibility

4. **Camera Clipping Planes**
   - Adjust near/far clip planes dynamically
   - Problem: Clips everything in the frustum, not selective geometry

5. **Alternative Map Design**
   - Design maps specifically for top-down play
   - Use minimal roofing, open structures
   - Problem: Defeats goal of supporting existing maps

**Assessment**: BSP is the hardest geometry type to handle. May require native code modifications or creative workarounds.

### StaticMeshes

**What they are**: Pre-built 3D mesh objects placed in maps. Trees, pillars, furniture, etc.

**Challenge**: StaticMeshes are actors but may have complex collision and multiple materials.

**Possible Approaches**:

1. **bHidden Flag**
   - Set `bHidden = true` to completely hide the mesh
   - Simple and efficient
   - Problem: Binary on/off, no transparency

2. **DrawScale Manipulation**
   - Scale to 0 to effectively hide
   - Problem: Affects collision

3. **Material Override**
   - Replace materials with transparent versions at runtime
   - Requires preparing transparent material variants
   - Most promising approach for StaticMeshes

4. **DrawType Modification**
   - Change DrawType to DT_None
   - Effectively hides the actor

5. **Collision Separation**
   - Spawn invisible collision proxy
   - Hide visual mesh
   - Maintains gameplay while removing visual

**Assessment**: StaticMeshes are manageable. `bHidden` or material swaps are viable.

### Movers

**What they are**: Moving BSP geometry - doors, lifts, platforms.

**Characteristics**: They're technically BSP but can be manipulated as actors.

**Possible Approaches**:
- Same as StaticMeshes: bHidden, DrawType, material override
- Movers maintain their own collision separate from visibility

**Assessment**: Movers should be similar to StaticMeshes in difficulty.

### Decorations

**What they are**: Smaller decorative actors (plants, debris, etc.)

**Assessment**: Easy to handle. Standard actor manipulation works.

### Terrain

**What it is**: Outdoor heightmapped surfaces.

**Challenge**: Terrain is a special rendering system with its own rules.

**Possible Approaches**:
- Terrain typically doesn't occlude from top-down views
- May need DecoLayers handling (grass, rocks placed on terrain)
- Probably not a major concern for occlusion

**Assessment**: Low priority. Terrain rarely occludes from above.

---

## Detection Methods

### Trace-Based Detection

The primary method for detecting occlusion is ray tracing from points of interest toward the camera.

#### Basic Trace

```unrealscript
function Actor TraceToCamera(Vector StartPoint)
{
    local Vector CameraLoc;
    local Rotator CameraRot;
    local Vector HitLocation, HitNormal;
    local Actor HitActor;

    // Get camera position
    PlayerController(Owner).GetPlayerViewPoint(CameraLoc, CameraRot);

    // Trace from point to camera
    HitActor = Trace(HitLocation, HitNormal, CameraLoc, StartPoint, true);

    return HitActor;
}
```

#### Limitations of Basic Trace
- Returns only the first hit
- BSP traces return `Level` as the hit actor, not specific geometry
- Cannot identify specific BSP surfaces
- Single ray may miss occluders near the point

#### Cone-Based Detection

To catch all potential occluders, we need multiple traces in a cone pattern:

```unrealscript
function array<Actor> ConeTraceToCamera(Vector StartPoint, float ConeAngle, int NumRays)
{
    local array<Actor> Occluders;
    local Vector CameraLoc, Direction, RayEnd;
    local Rotator CameraRot, RayRotation;
    local int i, j;
    local float AngleStep, CurrentAngle;

    PlayerController(Owner).GetPlayerViewPoint(CameraLoc, CameraRot);
    Direction = Normal(CameraLoc - StartPoint);

    // Central ray
    TraceAndCollect(StartPoint, CameraLoc, Occluders);

    // Cone rays
    AngleStep = ConeAngle / NumRays;
    for (i = 0; i < NumRays; i++)
    {
        CurrentAngle = (i + 1) * AngleStep;
        for (j = 0; j < 8; j++)  // 8 directions around cone
        {
            RayRotation = rotator(Direction);
            RayRotation.Yaw += (j * 8192);  // 360/8 = 45 degrees
            RayRotation.Pitch += int(CurrentAngle * 182.04);  // degrees to unreal units

            RayEnd = StartPoint + vector(RayRotation) * VSize(CameraLoc - StartPoint);
            TraceAndCollect(StartPoint, RayEnd, Occluders);
        }
    }

    return Occluders;
}
```

#### Performance Implications

- Each trace has CPU cost
- N waypoints × M rays per waypoint = N×M traces per update
- Example: 50 waypoints × 25 rays = 1,250 traces per frame
- At 60 FPS: 75,000 traces per second

**Mitigation Strategies**:
1. Reduce update frequency (every 3-5 frames instead of every frame)
2. Only trace for visible waypoints (frustum culling)
3. Cache results until camera moves significantly
4. Use coarse-to-fine: broad check first, detailed only if needed
5. Spatial partitioning to reduce waypoint count per check

### BSP-Specific Detection

Since `Trace()` against BSP returns `Level` rather than specific geometry, we need alternative approaches:

#### Zone Detection
```unrealscript
function ZoneInfo GetZoneAtPoint(Vector Point)
{
    // Returns the zone containing the point
    return Level.GetZoneAt(Point);
}
```

Zones might help identify regions, but don't give us specific surfaces.

#### Surface Texture Detection
```unrealscript
// After a trace hit on BSP
local name HitTexture;
HitTexture = TraceTexture(HitLocation, HitNormal, CameraLoc, StartPoint);
```

`TraceTexture` (if available) returns the texture at the hit point. This could help identify surfaces, but doesn't help modify them.

#### Collision Hash Detection
Some engine builds expose collision hash information that maps to BSP nodes. This is engine-version dependent.

---

## Rendering Modification Strategies

### Strategy A: Complete Hiding

**Method**: Set `bHidden = true` on occluding actors.

**Pros**:
- Simple to implement
- Zero rendering cost for hidden geometry
- Works for all actor types

**Cons**:
- Binary on/off (no fade transition)
- Jarring visual effect
- May hide geometry player should see

**Best For**: Initial implementation, fallback strategy

### Strategy B: Alpha Transparency

**Method**: Replace materials with transparent versions.

**Implementation**:
```unrealscript
function MakeActorTransparent(Actor A, float Alpha)
{
    local int i;

    // Store original materials
    if (A.OriginalMaterials.Length == 0)
    {
        A.OriginalMaterials = A.Skins;
    }

    // Apply transparent versions
    for (i = 0; i < A.Skins.Length; i++)
    {
        A.Skins[i] = GetTransparentVersion(A.OriginalMaterials[i], Alpha);
    }
}
```

**Pros**:
- Gradual fade possible
- Occluded geometry still visible as ghost
- Professional appearance

**Cons**:
- Requires transparent material variants for every texture
- Material generation overhead
- May not work for all material types
- BSP materials are shared; changing one affects all

**Best For**: StaticMeshes, Movers, high-quality implementation

### Strategy C: Wireframe Rendering

**Method**: Change render style to wireframe for occluders.

**Implementation**:
```unrealscript
function MakeActorWireframe(Actor A)
{
    A.Style = STY_Alpha;
    A.bUnlit = true;
    // Set special wireframe material
    A.Texture = Texture'Engine.WireframeMaterial';
}
```

**Pros**:
- Distinct visual indication
- Retains shape information
- Lower rendering cost than full alpha

**Cons**:
- Unusual visual style
- May not suit all game aesthetics
- Limited control over appearance

**Best For**: Debug mode, stylized implementations

### Strategy D: Silhouette Outline

**Method**: Hide geometry but draw outline where units are occluded.

**Implementation**:
- Draw unit silhouettes in screen space
- Or use projectors to mark occluded positions

**Pros**:
- Units always visible as silhouettes
- Doesn't modify map geometry
- Clear visual feedback

**Cons**:
- Complex to implement
- Doesn't show detailed unit state
- May require render-to-texture support

**Best For**: Alternative if geometry modification fails

### Strategy E: Hybrid Approach

**Method**: Combine multiple strategies based on geometry type.

**Implementation**:
- BSP: Use Strategy D (silhouette) or accept limitations
- StaticMeshes: Use Strategy B (transparency)
- Movers: Use Strategy A (hiding) or B (transparency)
- Decorations: Use Strategy A (hiding)

**Pros**:
- Handles each geometry type optimally
- Fallbacks available
- Practical compromise

**Cons**:
- More complex implementation
- Inconsistent visual style
- More code to maintain

**Best For**: Production implementation

---

## The BSP Problem

BSP geometry is the biggest challenge. Unlike actors, BSP surfaces cannot be individually hidden or made transparent at runtime.

### Why BSP Is Special

1. **Compiled Geometry**: BSP is compiled into a tree structure at map build time
2. **Shared Materials**: Textures/materials are applied to surfaces, not instanced
3. **No Actor Representation**: BSP isn't an actor; it's level geometry
4. **Zone-Based Rendering**: Visibility is controlled by zones, not per-surface

### Possible BSP Solutions

#### Solution 1: Accept Limitations

Design the game around BSP limitations:
- Use maps with minimal roofing
- Create custom maps for top-down play
- Focus on outdoor areas

**Assessment**: Defeats goal of supporting existing maps.

#### Solution 2: Zone Manipulation

If occluding BSP is in its own zone:
- Toggle zone visibility
- Problem: Zones are fixed at compile time

**Assessment**: Only works for specially designed maps.

#### Solution 3: Camera Clipping

Adjust camera near plane to clip through roofs:
- Set near clip plane beyond roof distance
- Problem: Clips ALL geometry at that distance

**Assessment**: Too coarse, causes other visual issues.

#### Solution 4: Native Code Modification

Modify the engine to support per-surface visibility:
- Requires C++ access
- Modify BSP rendering pipeline
- Add surface-level visibility flags

**Assessment**: Most powerful but requires native code and may affect stability.

#### Solution 5: Overlay Rendering

Render units on top of everything:
- Use special render pass for units
- Draw after all geometry
- Units "punch through" occluders

**Implementation Concept**:
```unrealscript
// In unit pawn class
defaultproperties
{
    // Render in special pass
    bUseLightingFromBase = false
    AmbientGlow = 128
    // Force rendering order
    // (actual implementation may require native support)
}
```

**Assessment**: May require render order manipulation not available in UnrealScript.

#### Solution 6: Proxy Actors

Place transparent proxy actors at ceiling locations:
- When ceiling would occlude, show the proxy
- Proxy is an actor and can be made transparent
- Problem: Requires knowing ceiling locations

**Assessment**: Complex setup, map-specific.

#### Solution 7: Alternative Camera Position

Instead of looking straight down:
- Use a lower camera angle (isometric-ish)
- Position camera to minimize occlusion
- Accept some occlusion as gameplay element

**Assessment**: Changes game design but may be most practical.

---

## Performance Optimization

### Spatial Partitioning

Use octree or grid-based partitioning to reduce checks:

```unrealscript
// Divide world into cells
// Only process waypoints in cells near camera view
function array<NavigationPoint> GetRelevantWaypoints()
{
    local array<NavigationPoint> Relevant;
    local Vector CameraLoc;
    local float ViewRadius;

    // Get camera frustum
    CameraLoc = GetCameraLocation();
    ViewRadius = CalculateViewRadius();

    // Only check waypoints in view
    foreach AllActors(class'NavigationPoint', NP)
    {
        if (VSize(NP.Location - CameraLoc) < ViewRadius)
        {
            if (IsInCameraFrustum(NP.Location))
            {
                Relevant.AddItem(NP);
            }
        }
    }

    return Relevant;
}
```

### Temporal Caching

Don't recalculate every frame:

```unrealscript
var Vector LastCameraLocation;
var Rotator LastCameraRotation;
var float OcclusionCacheTime;
var array<Actor> CachedOccluders;

function array<Actor> GetOccluders()
{
    local Vector CameraLoc;
    local Rotator CameraRot;

    GetPlayerViewPoint(CameraLoc, CameraRot);

    // Use cache if camera hasn't moved much
    if (VSize(CameraLoc - LastCameraLocation) < 50.0 &&
        Abs(CameraRot.Yaw - LastCameraRotation.Yaw) < 1000)
    {
        return CachedOccluders;
    }

    // Recalculate
    CachedOccluders = CalculateOccluders();
    LastCameraLocation = CameraLoc;
    LastCameraRotation = CameraRot;

    return CachedOccluders;
}
```

### Level-of-Detail Tracing

Use fewer rays for distant waypoints:

```unrealscript
function int GetRayCountForDistance(float Distance)
{
    if (Distance > 5000)
        return 4;   // Distant: few rays
    else if (Distance > 2000)
        return 9;   // Medium: moderate rays
    else
        return 25;  // Close: detailed rays
}
```

### Update Frequency Scaling

Reduce update rate based on camera speed:

```unrealscript
var float LastOcclusionUpdate;
var float OcclusionUpdateInterval;

function Tick(float DeltaTime)
{
    local float CameraSpeed;

    CameraSpeed = GetCameraMovementSpeed();

    // Fast movement: update more frequently
    // Slow/stopped: update less frequently
    if (CameraSpeed > 500)
        OcclusionUpdateInterval = 0.033;  // 30 Hz
    else if (CameraSpeed > 100)
        OcclusionUpdateInterval = 0.1;    // 10 Hz
    else
        OcclusionUpdateInterval = 0.25;   // 4 Hz

    if (Level.TimeSeconds - LastOcclusionUpdate > OcclusionUpdateInterval)
    {
        UpdateOcclusion();
        LastOcclusionUpdate = Level.TimeSeconds;
    }
}
```

---

## Multiplayer Considerations

Each player has their own camera position, requiring separate occlusion calculations.

### Per-Player Occlusion State

```unrealscript
struct PlayerOcclusionState
{
    var PlayerController Player;
    var array<Actor> OccludedActors;
    var Vector LastCameraLoc;
    var float LastUpdateTime;
};

var array<PlayerOcclusionState> PlayerStates;
```

### Client-Side vs Server-Side

**Server-Side Calculation**:
- Consistent across all clients
- Higher server load
- Requires replication of occlusion state

**Client-Side Calculation**:
- Each client calculates own occlusion
- Reduces server load
- No replication needed
- Potential for inconsistency (usually acceptable for visual-only effects)

**Recommendation**: Client-side calculation for visual occlusion. Gameplay visibility should remain server-authoritative.

### Network Bandwidth

If replicating occlusion state:
- Only replicate changes (delta compression)
- Use actor reference IDs, not full data
- Batch updates rather than per-actor

---

## Research Tasks

Before implementation, these questions need answers:

### Critical Research

1. **BSP Trace Identification**: Can we identify specific BSP surfaces from trace results? Test `TraceTexture`, surface flags, etc.

2. **Material Runtime Modification**: Can we create and apply new materials at runtime? What are the limits?

3. **Zone Visibility Control**: What happens when we toggle zone visibility flags? Does it affect specific geometry or entire zones?

4. **Render Order Control**: Can we force certain actors to render after/on-top-of BSP? What properties affect this?

5. **Native Code Access**: What level of engine source access is available? Can we modify rendering?

### Performance Research

6. **Trace Performance**: How many traces per frame are acceptable? Benchmark on target hardware.

7. **Material Swap Cost**: What's the performance impact of frequent material changes?

8. **Actor Hide/Show Cost**: Is there overhead to toggling `bHidden`?

### Visual Research

9. **Transparency Appearance**: How do transparent materials look over UT2004 textures? Does it look acceptable?

10. **Fade Transitions**: Can we smoothly fade geometry in/out? What's the visual quality?

---

## Implementation Phases

Given the complexity, the occlusion system should be built incrementally:

### Phase 7a: Occlusion Detection Framework
- Implement basic trace system
- Detect actors between waypoints and camera
- No rendering modifications yet
- Debug visualization of detected occluders

### Phase 7b: Actor Occlusion Handling
- Implement hiding/transparency for StaticMeshes
- Handle Movers and Decorations
- Create material management system
- Test on various maps

### Phase 7c: BSP Research and Prototyping
- Research BSP modification possibilities
- Prototype different approaches
- Document what works and what doesn't
- Decide on BSP strategy

### Phase 7d: BSP Occlusion Implementation
- Implement chosen BSP strategy
- Handle edge cases
- Integrate with actor occlusion

### Phase 7e: Performance Optimization
- Profile occlusion system
- Implement caching and LOD
- Optimize trace patterns
- Test multiplayer performance

### Phase 7f: Visual Polish
- Fade transitions
- Edge case handling
- Visual consistency
- User feedback integration

---

## Fallback Strategies

If full dynamic occlusion proves impossible:

### Fallback 1: Design-Based Solution
- Recommend/require maps designed for top-down play
- Provide map design guidelines
- Create example maps

### Fallback 2: Partial Occlusion
- Handle actor occlusion only (ignore BSP)
- Accept that some geometry will occlude
- Mitigate with camera angle adjustments

### Fallback 3: Silhouette System
- Don't modify geometry
- Instead, draw unit silhouettes through occluders
- Requires render-to-texture or canvas drawing

### Fallback 4: Minimap Enhancement
- If units are occluded, show them on minimap
- Provide enough information for gameplay
- Accept limited direct visibility

---

## Related Documents

- [002-rendering-system.md](002-rendering-system.md) - Overview document
- [005-roadmap.md](005-roadmap.md) - Phase 7 in project roadmap
- `notes/vision` - Original vision document
- `issues/7*` - Phase 7 issue files

## Technical References

- UnrealWiki: Actor Visibility
- UnrealWiki: BSP Optimization
- UnrealWiki: Materials and Textures
- UT2004 UnrealScript Source (Epic Games)
