# Issue 701a: Occlusion Detection Framework

## Status
- Phase: 7
- Priority: Critical
- Status: Open
- Dependencies: Phase 2 (Camera System)
- Parent Issue: 701-dynamic-occlusion-system

## Current Behavior

No system exists to detect which geometry is between the camera and units/waypoints.

## Intended Behavior

A framework that:
1. Identifies all AI waypoints visible in the camera's view
2. Casts rays from waypoints toward the camera
3. Detects all geometry (actors and BSP) that intersects those rays
4. Provides a list of occluding geometry for further processing
5. Operates efficiently enough for real-time use

## Suggested Implementation Steps

### 1. Create Occlusion Manager Class

```unrealscript
// {{{ class SR_OcclusionManager
class SR_OcclusionManager extends Info;

var PlayerController OwningPlayer;
var array<Actor> CurrentOccluders;
var array<NavigationPoint> RelevantWaypoints;

var Vector CachedCameraLocation;
var Rotator CachedCameraRotation;
var float LastUpdateTime;
var float UpdateInterval;

var config int RaysPerWaypoint;
var config float ConeAngleDegrees;
var config float MaxDetectionDistance;

function PostBeginPlay()
{
    Super.PostBeginPlay();
    UpdateInterval = 0.05;  // 20 Hz default
    RaysPerWaypoint = 9;
    ConeAngleDegrees = 15.0;
    MaxDetectionDistance = 10000.0;
}
// }}}
```

### 2. Implement Waypoint Filtering

Only check waypoints that are:
- Within camera view frustum
- Within maximum detection distance
- Not already fully visible (quick pre-check)

```unrealscript
// {{{ function GetRelevantWaypoints
function array<NavigationPoint> GetRelevantWaypoints()
{
    local array<NavigationPoint> Result;
    local NavigationPoint NP;
    local Vector CameraLoc;
    local Rotator CameraRot;
    local Vector ToWaypoint;
    local float Distance;

    OwningPlayer.GetPlayerViewPoint(CameraLoc, CameraRot);

    foreach AllActors(class'NavigationPoint', NP)
    {
        ToWaypoint = NP.Location - CameraLoc;
        Distance = VSize(ToWaypoint);

        // Skip if too far
        if (Distance > MaxDetectionDistance)
            continue;

        // Skip if behind camera
        if ((ToWaypoint dot vector(CameraRot)) < 0)
            continue;

        // TODO: Full frustum check

        Result.AddItem(NP);
    }

    return Result;
}
// }}}
```

### 3. Implement Basic Trace System

Single ray from waypoint to camera:

```unrealscript
// {{{ function TraceToCamera
function Actor TraceToCamera(Vector StartPoint, out Vector HitLocation, out Vector HitNormal)
{
    local Vector CameraLoc;
    local Rotator CameraRot;
    local Actor HitActor;

    OwningPlayer.GetPlayerViewPoint(CameraLoc, CameraRot);

    HitActor = Trace(HitLocation, HitNormal, CameraLoc, StartPoint, true);

    return HitActor;
}
// }}}
```

### 4. Implement Cone Trace System

Multiple rays in a cone pattern for thorough detection:

```unrealscript
// {{{ function ConeTraceToCamera
function array<Actor> ConeTraceToCamera(Vector StartPoint)
{
    local array<Actor> Occluders;
    local Vector CameraLoc, Direction, TraceEnd;
    local Rotator CameraRot, BaseRot, TraceRot;
    local Vector HitLoc, HitNorm;
    local Actor HitActor;
    local int Ring, Spoke;
    local float RingAngle, SpokeAngle;
    local float ConeRadians;

    OwningPlayer.GetPlayerViewPoint(CameraLoc, CameraRot);
    Direction = Normal(CameraLoc - StartPoint);
    BaseRot = rotator(Direction);
    ConeRadians = ConeAngleDegrees * PI / 180.0;

    // Central ray
    HitActor = Trace(HitLoc, HitNorm, CameraLoc, StartPoint, true);
    if (HitActor != None)
        AddUniqueOccluder(Occluders, HitActor);

    // Cone rings
    for (Ring = 1; Ring <= 2; Ring++)
    {
        RingAngle = (ConeRadians * Ring) / 2.0;

        // Spokes around ring
        for (Spoke = 0; Spoke < 8; Spoke++)
        {
            SpokeAngle = (Spoke * 2.0 * PI) / 8.0;

            TraceRot = BaseRot;
            TraceRot.Pitch += int((Sin(SpokeAngle) * RingAngle) * 10430.0);
            TraceRot.Yaw += int((Cos(SpokeAngle) * RingAngle) * 10430.0);

            TraceEnd = StartPoint + vector(TraceRot) * VSize(CameraLoc - StartPoint);

            HitActor = Trace(HitLoc, HitNorm, TraceEnd, StartPoint, true);
            if (HitActor != None)
                AddUniqueOccluder(Occluders, HitActor);
        }
    }

    return Occluders;
}
// }}}
```

### 5. Implement BSP Detection Handling

When trace hits BSP, it returns `Level` as the actor. We need to handle this specially:

```unrealscript
// {{{ function AddUniqueOccluder
function AddUniqueOccluder(out array<Actor> List, Actor NewOccluder)
{
    local int i;

    // Check if it's BSP (Level actor)
    if (NewOccluder == Level)
    {
        // Record BSP hit differently
        // TODO: See Issue 701c for BSP handling
        RecordBSPHit();
        return;
    }

    // Skip self, player, and units
    if (ShouldIgnoreActor(NewOccluder))
        return;

    // Check for duplicates
    for (i = 0; i < List.Length; i++)
    {
        if (List[i] == NewOccluder)
            return;
    }

    List.AddItem(NewOccluder);
}
// }}}

// {{{ function ShouldIgnoreActor
function bool ShouldIgnoreActor(Actor A)
{
    // Ignore players and units
    if (A.IsA('Pawn'))
        return true;

    // Ignore pickups
    if (A.IsA('Pickup'))
        return true;

    // Ignore projectiles
    if (A.IsA('Projectile'))
        return true;

    // Ignore effects
    if (A.IsA('Emitter'))
        return true;

    return false;
}
// }}}
```

### 6. Implement Update Loop

```unrealscript
// {{{ function UpdateOcclusion
function UpdateOcclusion()
{
    local array<Actor> NewOccluders;
    local NavigationPoint NP;
    local array<Actor> WaypointOccluders;
    local int i;

    // Get waypoints to check
    RelevantWaypoints = GetRelevantWaypoints();

    // Clear and rebuild occluder list
    NewOccluders.Length = 0;

    // Trace from each waypoint
    for (i = 0; i < RelevantWaypoints.Length; i++)
    {
        NP = RelevantWaypoints[i];
        WaypointOccluders = ConeTraceToCamera(NP.Location);

        // Merge into main list
        MergeOccluders(NewOccluders, WaypointOccluders);
    }

    // Track changes for transition effects
    NotifyOcclusionChanges(CurrentOccluders, NewOccluders);

    CurrentOccluders = NewOccluders;
}
// }}}

// {{{ function Tick
function Tick(float DeltaTime)
{
    Super.Tick(DeltaTime);

    if (Level.TimeSeconds - LastUpdateTime > UpdateInterval)
    {
        UpdateOcclusion();
        LastUpdateTime = Level.TimeSeconds;
    }
}
// }}}
```

### 7. Create Debug Visualization

Essential for development and testing:

```unrealscript
// {{{ function DrawDebugOcclusion
function DrawDebugOcclusion(Canvas C)
{
    local int i;
    local Vector ScreenPos;
    local Actor Occ;

    // Draw detected occluders
    for (i = 0; i < CurrentOccluders.Length; i++)
    {
        Occ = CurrentOccluders[i];

        // Draw box around occluder
        DrawDebugBox(Occ.Location, Occ.CollisionRadius, Occ.CollisionHeight, 255, 0, 0);

        // Draw line from camera to occluder
        DrawDebugLine(CachedCameraLocation, Occ.Location, 255, 255, 0);
    }

    // Draw checked waypoints
    for (i = 0; i < RelevantWaypoints.Length; i++)
    {
        DrawDebugSphere(RelevantWaypoints[i].Location, 50, 8, 0, 255, 0);
    }

    // HUD stats
    C.SetPos(10, 100);
    C.DrawText("Occluders: " $ CurrentOccluders.Length);
    C.SetPos(10, 120);
    C.DrawText("Waypoints Checked: " $ RelevantWaypoints.Length);
}
// }}}
```

### 8. Create Console Commands for Testing

```unrealscript
// {{{ exec functions
exec function OcclusionDebug()
{
    bShowDebugOcclusion = !bShowDebugOcclusion;
    Log("Occlusion debug:" @ bShowDebugOcclusion);
}

exec function OcclusionStats()
{
    Log("=== Occlusion Stats ===");
    Log("Current Occluders:" @ CurrentOccluders.Length);
    Log("Relevant Waypoints:" @ RelevantWaypoints.Length);
    Log("Update Interval:" @ UpdateInterval);
    Log("Last Update:" @ LastUpdateTime);
}
// }}}
```

### 9. Test on Multiple Maps

Create test script to verify detection on:
- DM-Rankin (indoor/outdoor mix)
- DM-Deck17 (multi-level)
- ONS-Torlan (large outdoor)
- DM-1on1-Roughinery (tight indoor)

Document which geometry types are detected and which are missed.

## Related Documents
- docs/006-rendering-system-technical.md
- issues/701-dynamic-occlusion-system.md (parent)

## Technical Notes

### Trace Function Behavior
- `Trace()` returns first hit actor
- BSP hits return `Level` as the actor
- `bTraceActors` parameter controls whether actors are checked
- `bTraceWorld` controls BSP tracing

### Unreal Units
- Rotation: 65536 units = 360 degrees
- 1 degree = ~182 units
- 1 radian = ~10430 units

### Performance Baseline
Target: <2ms per update on reference hardware
Track: traces/second, actors checked, waypoints processed

## Acceptance Criteria

- [ ] SR_OcclusionManager class created and compiles
- [ ] Can detect actors between waypoints and camera
- [ ] Correctly identifies StaticMeshes as occluders
- [ ] Correctly identifies Movers as occluders
- [ ] Records BSP hits (handling deferred to 701c)
- [ ] Debug visualization shows detection working
- [ ] Console commands for testing work
- [ ] Tested on 3+ different map types
- [ ] Performance acceptable (<2ms per update)
- [ ] No crashes or errors in log

## Notes

This is the foundation for all occlusion work. Take time to get it right.

The cone trace parameters (RaysPerWaypoint, ConeAngleDegrees) will need tuning based on testing. Start conservative and optimize later.

BSP detection is recorded here but actual handling is deferred to Issues 701c and 701d.
