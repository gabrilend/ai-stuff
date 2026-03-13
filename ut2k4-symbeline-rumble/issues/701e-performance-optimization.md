# Issue 701e: Occlusion Performance Optimization

## Status
- Phase: 7
- Priority: High
- Status: Open
- Dependencies: 701b-actor-occlusion-handling, 701d-bsp-occlusion-implementation
- Parent Issue: 701-dynamic-occlusion-system

## Current Behavior

After Issues 701a-701d, occlusion detection and handling works but may not meet performance targets. Initial implementation prioritizes correctness over speed.

## Intended Behavior

Occlusion system meets performance targets:
- **Frame Time**: <2ms per occlusion update
- **Frame Rate**: No more than 5 FPS drop with occlusion active
- **Scalability**: Works with 50+ waypoints, 20+ units
- **Multiplayer**: Handles 4+ players without significant degradation

## Performance Targets

### Trace Budget
- Target: <500 traces per frame
- Rationale: ~0.001ms per trace × 500 = 0.5ms trace time

### Memory Budget
- Occlusion state arrays: <100KB
- Cached data: <50KB per player
- Material instances: <1MB total

### Update Frequency
- Moving camera: 20-30 Hz updates
- Static camera: 4-10 Hz updates
- Out of combat: 2-4 Hz updates

## Optimization Strategies

### 1. Spatial Partitioning

Divide world into cells to reduce waypoint checking:

```unrealscript
// {{{ struct OcclusionCell
struct OcclusionCell
{
    var Vector Min;
    var Vector Max;
    var array<NavigationPoint> Waypoints;
    var array<Actor> Occluders;
    var bool bInView;
    var float LastCheckTime;
};

var array<OcclusionCell> WorldCells;
var int CellsPerAxis;  // e.g., 8x8x4 grid
// }}}

// {{{ function InitializeSpatialPartition
function InitializeSpatialPartition()
{
    local Vector WorldMin, WorldMax;
    local Vector CellSize;
    local int x, y, z;
    local OcclusionCell Cell;
    local NavigationPoint NP;

    // Get world bounds
    GetWorldBounds(WorldMin, WorldMax);

    // Calculate cell size
    CellSize = (WorldMax - WorldMin) / CellsPerAxis;

    // Create cells
    for (x = 0; x < CellsPerAxis; x++)
    {
        for (y = 0; y < CellsPerAxis; y++)
        {
            for (z = 0; z < CellsPerAxis / 2; z++)
            {
                Cell.Min = WorldMin + vect(x, y, z) * CellSize;
                Cell.Max = Cell.Min + CellSize;
                Cell.bInView = false;
                WorldCells.AddItem(Cell);
            }
        }
    }

    // Assign waypoints to cells
    foreach AllActors(class'NavigationPoint', NP)
    {
        AssignToCell(NP);
    }
}
// }}}

// {{{ function GetCellsInView
function array<OcclusionCell> GetCellsInView()
{
    local array<OcclusionCell> Result;
    local int i;
    local Vector CameraLoc;
    local Rotator CameraRot;

    GetPlayerViewPoint(CameraLoc, CameraRot);

    for (i = 0; i < WorldCells.Length; i++)
    {
        if (IsCellInFrustum(WorldCells[i], CameraLoc, CameraRot))
        {
            Result.AddItem(WorldCells[i]);
        }
    }

    return Result;
}
// }}}
```

### 2. Temporal Caching

Don't recalculate when camera hasn't moved:

```unrealscript
// {{{ var CacheVariables
var Vector CachedCameraLocation;
var Rotator CachedCameraRotation;
var float CacheValidDistance;      // Distance camera must move to invalidate
var float CacheValidAngle;         // Rotation change to invalidate
var array<Actor> CachedOccluders;
var float CacheTime;
var float CacheMaxAge;             // Force refresh after this time
// }}}

// {{{ function IsCacheValid
function bool IsCacheValid()
{
    local Vector CameraLoc;
    local Rotator CameraRot;
    local float DistanceMoved;
    local int AngleChanged;

    // Check age
    if (Level.TimeSeconds - CacheTime > CacheMaxAge)
        return false;

    GetPlayerViewPoint(CameraLoc, CameraRot);

    // Check distance moved
    DistanceMoved = VSize(CameraLoc - CachedCameraLocation);
    if (DistanceMoved > CacheValidDistance)
        return false;

    // Check rotation changed
    AngleChanged = Abs(CameraRot.Yaw - CachedCameraRotation.Yaw);
    if (AngleChanged > CacheValidAngle)
        return false;

    return true;
}
// }}}
```

### 3. Level-of-Detail Tracing

Fewer rays for distant or less important waypoints:

```unrealscript
// {{{ function GetTraceDetailLevel
function int GetTraceDetailLevel(NavigationPoint NP)
{
    local float Distance;
    local Vector CameraLoc;

    CameraLoc = GetCameraLocation();
    Distance = VSize(NP.Location - CameraLoc);

    // Very close: full detail
    if (Distance < 1000)
        return 25;  // 25 rays

    // Medium distance
    if (Distance < 3000)
        return 9;   // 9 rays

    // Far: minimal
    if (Distance < 6000)
        return 4;   // 4 rays

    // Very far: single ray
    return 1;
}
// }}}
```

### 4. Incremental Updates

Don't update all waypoints every frame:

```unrealscript
// {{{ var IncrementalState
var int CurrentWaypointIndex;
var int WaypointsPerFrame;
var array<NavigationPoint> AllWaypoints;
// }}}

// {{{ function IncrementalUpdate
function IncrementalUpdate()
{
    local int i;
    local int EndIndex;
    local NavigationPoint NP;

    EndIndex = Min(CurrentWaypointIndex + WaypointsPerFrame,
                   AllWaypoints.Length);

    for (i = CurrentWaypointIndex; i < EndIndex; i++)
    {
        NP = AllWaypoints[i];
        UpdateWaypointOcclusion(NP);
    }

    CurrentWaypointIndex = EndIndex;

    // Wrap around
    if (CurrentWaypointIndex >= AllWaypoints.Length)
        CurrentWaypointIndex = 0;
}
// }}}
```

### 5. Adaptive Update Rate

Update faster when camera is moving:

```unrealscript
// {{{ function GetAdaptiveUpdateInterval
function float GetAdaptiveUpdateInterval()
{
    local float CameraSpeed;
    local float Interval;

    CameraSpeed = VSize(CameraVelocity);

    // Fast movement: high update rate
    if (CameraSpeed > 800)
        return 0.016;  // ~60 Hz

    if (CameraSpeed > 400)
        return 0.033;  // ~30 Hz

    if (CameraSpeed > 100)
        return 0.066;  // ~15 Hz

    // Slow/stopped: low update rate
    return 0.1;        // 10 Hz
}
// }}}
```

### 6. Material Instance Pooling

Reuse transparent materials instead of creating new ones:

```unrealscript
// {{{ struct MaterialPool
var array<Material> TransparentMaterialPool;
var int PoolSize;
var int NextPoolIndex;
// }}}

// {{{ function GetPooledMaterial
function Material GetPooledMaterial()
{
    local Material Mat;

    Mat = TransparentMaterialPool[NextPoolIndex];
    NextPoolIndex = (NextPoolIndex + 1) % PoolSize;

    return Mat;
}
// }}}
```

### 7. Early Culling

Skip traces that can't possibly hit occluders:

```unrealscript
// {{{ function ShouldSkipWaypoint
function bool ShouldSkipWaypoint(NavigationPoint NP)
{
    local Vector CameraLoc;
    local Vector ToWaypoint;

    CameraLoc = GetCameraLocation();
    ToWaypoint = NP.Location - CameraLoc;

    // Skip if waypoint is above camera (can't be occluded from above)
    if (NP.Location.Z > CameraLoc.Z)
        return true;

    // Skip if already confirmed clear recently
    if (NP.bOcclusionClear && Level.TimeSeconds - NP.LastOcclusionCheck < 0.5)
        return true;

    return false;
}
// }}}
```

### 8. Batch Visibility Changes

Group actor visibility changes to reduce overhead:

```unrealscript
// {{{ function BatchApplyOcclusionChanges
function BatchApplyOcclusionChanges(array<Actor> ToHide, array<Actor> ToShow)
{
    local int i;

    // Apply all hides
    for (i = 0; i < ToHide.Length; i++)
    {
        ToHide[i].bHidden = true;
    }

    // Apply all shows
    for (i = 0; i < ToShow.Length; i++)
    {
        ToShow[i].bHidden = false;
    }
}
// }}}
```

## Profiling

### Metrics to Track

```unrealscript
// {{{ struct OcclusionMetrics
struct OcclusionMetrics
{
    var int TracesThisFrame;
    var int WaypointsChecked;
    var int OccludersFound;
    var int ActorChangesThisFrame;
    var float UpdateTimeMS;
    var float AverageUpdateTimeMS;
    var int CacheHits;
    var int CacheMisses;
};
// }}}
```

### Debug Output

```unrealscript
// {{{ function DrawOcclusionStats
function DrawOcclusionStats(Canvas C)
{
    C.SetPos(10, 200);
    C.DrawText("=== Occlusion Performance ===");
    C.SetPos(10, 220);
    C.DrawText("Traces/Frame: " $ Metrics.TracesThisFrame);
    C.SetPos(10, 240);
    C.DrawText("Waypoints Checked: " $ Metrics.WaypointsChecked);
    C.SetPos(10, 260);
    C.DrawText("Update Time: " $ Metrics.UpdateTimeMS $ "ms");
    C.SetPos(10, 280);
    C.DrawText("Cache Hit Rate: " $
        (Metrics.CacheHits * 100 / (Metrics.CacheHits + Metrics.CacheMisses)) $ "%");
}
// }}}
```

### Console Commands

```unrealscript
// {{{ exec function OcclusionProfile
exec function OcclusionProfile(int Seconds)
{
    local float StartTime;
    local int Frames;

    Log("=== Occlusion Profiling Start ===");

    StartTime = Level.TimeSeconds;
    ResetMetrics();
    bProfiling = true;

    // After Seconds, log results
    SetTimer(Seconds, false);
}
// }}}

// {{{ exec function OcclusionBudget
exec function OcclusionBudget(float MaxMS)
{
    MaxUpdateTimeMS = MaxMS;
    Log("Occlusion budget set to" @ MaxMS $ "ms");
}
// }}}
```

## Multiplayer Optimization

### Client-Side Processing

```unrealscript
// {{{ function UpdateOcclusionClient
simulated function UpdateOcclusionClient()
{
    // Each client calculates own occlusion
    // No replication needed for visual-only effect

    if (Role == ROLE_Authority)
        return;  // Server doesn't need visual occlusion

    DoOcclusionUpdate();
}
// }}}
```

### Shared Computations

For expensive computations, server can provide hints:

```unrealscript
// {{{ replication
replication
{
    reliable if (Role == ROLE_Authority)
        OcclusionHints;  // Server-computed expensive data
}
// }}}
```

## Configuration

Allow users to adjust performance vs quality:

```unrealscript
// {{{ var OcclusionQuality
var config enum EOcclusionQuality
{
    OQ_Low,      // Minimal traces, binary hide/show
    OQ_Medium,   // Moderate traces, simple transitions
    OQ_High,     // Full traces, smooth transitions
    OQ_Ultra     // Maximum quality, all features
} OcclusionQuality;
// }}}

// {{{ function ApplyQualitySettings
function ApplyQualitySettings()
{
    switch (OcclusionQuality)
    {
        case OQ_Low:
            WaypointsPerFrame = 5;
            RaysPerWaypoint = 1;
            bEnableTransitions = false;
            UpdateInterval = 0.1;
            break;

        case OQ_Medium:
            WaypointsPerFrame = 10;
            RaysPerWaypoint = 4;
            bEnableTransitions = true;
            UpdateInterval = 0.066;
            break;

        case OQ_High:
            WaypointsPerFrame = 20;
            RaysPerWaypoint = 9;
            bEnableTransitions = true;
            UpdateInterval = 0.033;
            break;

        case OQ_Ultra:
            WaypointsPerFrame = 50;
            RaysPerWaypoint = 25;
            bEnableTransitions = true;
            UpdateInterval = 0.016;
            break;
    }
}
// }}}
```

## Related Documents
- docs/006-rendering-system-technical.md (Performance section)
- issues/701a-occlusion-detection-framework.md
- issues/701b-actor-occlusion-handling.md
- issues/701-dynamic-occlusion-system.md (parent)

## Acceptance Criteria

- [ ] Frame time budget (<2ms) met on reference hardware
- [ ] FPS drop <5 with occlusion active
- [ ] Works with 50+ waypoints
- [ ] Works with 20+ active units
- [ ] Multiplayer performance acceptable (4 players)
- [ ] Quality settings implemented
- [ ] Profiling tools functional
- [ ] Cache hit rate >60%
- [ ] No memory leaks
- [ ] Performance documented

## Notes

Optimization should happen AFTER functionality is correct. Don't optimize prematurely.

Profile first, optimize second. Identify actual bottlenecks rather than guessing.

Some optimizations may reduce visual quality. Document tradeoffs.

Quality settings allow users to choose their own balance between performance and visuals.
