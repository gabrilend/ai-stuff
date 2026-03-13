# Issue 701f: Occlusion Visual Polish

## Status
- Phase: 7
- Priority: Medium
- Status: Open
- Dependencies: 701e-performance-optimization
- Parent Issue: 701-dynamic-occlusion-system

## Current Behavior

After Issues 701a-701e, occlusion system is functional and performant, but may have visual rough edges:
- Abrupt transitions
- Inconsistent appearance
- Edge cases causing visual glitches
- Lack of feedback for partially occluded units

## Intended Behavior

Polished visual presentation that:
1. Smoothly transitions occluded geometry
2. Provides clear feedback about occlusion state
3. Handles edge cases gracefully
4. Looks professional and intentional

## Polish Areas

### 1. Smooth Fade Transitions

Implement easing functions for smoother fades:

```unrealscript
// {{{ function EaseInOutCubic
function float EaseInOutCubic(float T)
{
    if (T < 0.5)
        return 4 * T * T * T;
    else
        return 1 - ((-2 * T + 2) ** 3) / 2;
}
// }}}

// {{{ function UpdateTransitionSmooth
function UpdateTransitionSmooth(out OcclusionState State, float DeltaTime)
{
    local float Progress;
    local float Duration;

    Duration = 0.3;  // 300ms transition

    State.TransitionTime += DeltaTime;
    Progress = FClamp(State.TransitionTime / Duration, 0.0, 1.0);

    // Apply easing
    Progress = EaseInOutCubic(Progress);

    // Interpolate alpha
    State.CurrentAlpha = Lerp(State.StartAlpha, State.TargetAlpha, Progress);
}
// }}}
```

### 2. Ghost/Silhouette Effect

Instead of just hiding, show ghosted geometry:

```unrealscript
// {{{ function ApplyGhostEffect
function ApplyGhostEffect(Actor A, float Intensity)
{
    local Material GhostMat;

    // Create ghost material
    GhostMat = GetGhostMaterial();

    // Apply with intensity-based color
    A.Skins[0] = GhostMat;
    A.Style = STY_Translucent;

    // Set ghost color (blue-ish tint)
    A.AmbientGlow = int(64 * Intensity);
}
// }}}
```

### 3. Outline Rendering for Units

When units are occluded, draw outline through geometry:

```unrealscript
// {{{ function DrawOccludedUnitIndicator
function DrawOccludedUnitIndicator(Canvas C, Pawn Unit)
{
    local Vector ScreenPos;
    local float OcclusionAmount;

    // Get screen position
    ScreenPos = C.WorldToScreen(Unit.Location);

    // Calculate occlusion amount (0-1)
    OcclusionAmount = GetUnitOcclusionAmount(Unit);

    if (OcclusionAmount > 0.5)
    {
        // Draw outline circle
        C.SetDrawColor(255, 255, 0, 200);  // Yellow
        DrawCircle(C, ScreenPos.X, ScreenPos.Y, 20, 16);

        // Draw unit type icon
        DrawUnitIcon(C, Unit, ScreenPos);
    }
}
// }}}
```

### 4. Partial Occlusion Handling

Different treatment based on how much is occluded:

```unrealscript
// {{{ enum EOcclusionLevel
enum EOcclusionLevel
{
    OL_None,      // Fully visible
    OL_Partial,   // Some rays hit occluders
    OL_Heavy,     // Most rays hit occluders
    OL_Full       // Completely occluded
};
// }}}

// {{{ function GetOcclusionLevel
function EOcclusionLevel GetOcclusionLevel(float OcclusionRatio)
{
    if (OcclusionRatio < 0.1)
        return OL_None;
    if (OcclusionRatio < 0.4)
        return OL_Partial;
    if (OcclusionRatio < 0.8)
        return OL_Heavy;
    return OL_Full;
}
// }}}

// {{{ function ApplyOcclusionVisual
function ApplyOcclusionVisual(Actor A, EOcclusionLevel Level)
{
    switch (Level)
    {
        case OL_None:
            RestoreFullVisibility(A);
            break;

        case OL_Partial:
            // Slight transparency, no outline
            SetActorAlpha(A, 0.85);
            break;

        case OL_Heavy:
            // More transparent, consider outline
            SetActorAlpha(A, 0.5);
            break;

        case OL_Full:
            // Very transparent or hidden, with outline
            SetActorAlpha(A, 0.2);
            break;
    }
}
// }}}
```

### 5. Edge Flickering Prevention

Prevent rapid on/off flickering at edges:

```unrealscript
// {{{ var HysteresisSettings
var float OcclusionOnThreshold;    // Must exceed to become occluded
var float OcclusionOffThreshold;   // Must fall below to become visible
var float MinOcclusionDuration;    // Minimum time before state change
// }}}

// {{{ function ShouldChangeOcclusionState
function bool ShouldChangeOcclusionState(OcclusionState State, float NewRatio)
{
    local float TimeSinceChange;

    TimeSinceChange = Level.TimeSeconds - State.LastStateChangeTime;

    // Require minimum duration
    if (TimeSinceChange < MinOcclusionDuration)
        return false;

    // Hysteresis: different thresholds for on/off
    if (State.bOccluded)
    {
        // Currently occluded, need to fall below off threshold
        return NewRatio < OcclusionOffThreshold;
    }
    else
    {
        // Currently visible, need to exceed on threshold
        return NewRatio > OcclusionOnThreshold;
    }
}
// }}}
```

### 6. Distance-Based Fade

Fade effect based on distance from camera:

```unrealscript
// {{{ function GetDistanceFade
function float GetDistanceFade(Actor A)
{
    local float Distance;
    local float FadeStart;
    local float FadeEnd;

    Distance = VSize(A.Location - CameraLocation);

    FadeStart = 5000;  // Start fading at this distance
    FadeEnd = 8000;    // Fully faded at this distance

    if (Distance < FadeStart)
        return 1.0;
    if (Distance > FadeEnd)
        return 0.3;  // Minimum visibility

    return Lerp(1.0, 0.3, (Distance - FadeStart) / (FadeEnd - FadeStart));
}
// }}}
```

### 7. Material Quality Improvements

Better transparent materials for different surface types:

```unrealscript
// {{{ function GetBestTransparentMaterial
function Material GetBestTransparentMaterial(Actor A, float Alpha)
{
    // Check actor type for best material
    if (A.IsA('StaticMeshActor'))
    {
        // Use shader with preserved texture
        return CreateTexturedTransparent(A.Skins[0], Alpha);
    }
    else if (A.IsA('Mover'))
    {
        // Movers may need special handling
        return CreateMoverTransparent(Alpha);
    }
    else
    {
        // Generic transparent
        return GenericTransparentMaterial;
    }
}
// }}}
```

### 8. Sound Feedback

Optional audio cue when occlusion changes:

```unrealscript
// {{{ function PlayOcclusionSound
function PlayOcclusionSound(bool bBecomingOccluded)
{
    if (!bEnableOcclusionSounds)
        return;

    if (bBecomingOccluded)
    {
        // Subtle "whoosh" as geometry fades
        PlaySound(OcclusionFadeOutSound, SLOT_Misc, 0.3);
    }
    else
    {
        // Subtle "pop" as geometry returns
        PlaySound(OcclusionFadeInSound, SLOT_Misc, 0.2);
    }
}
// }}}
```

### 9. Configuration Options

User-facing options for occlusion appearance:

```unrealscript
// {{{ var UserConfig
var config enum EOcclusionStyle
{
    OS_Hide,          // Completely hide occluders
    OS_Transparent,   // Semi-transparent
    OS_Ghost,         // Ghost/silhouette effect
    OS_Wireframe      // Wireframe rendering
} OcclusionStyle;

var config float OcclusionTransparency;  // 0.0 - 1.0
var config bool bShowOccludedUnitOutlines;
var config bool bEnableOcclusionSounds;
var config float TransitionDuration;
// }}}
```

### 10. Debug Visualization Enhancement

Improved debug display for development:

```unrealscript
// {{{ function DrawEnhancedDebug
function DrawEnhancedDebug(Canvas C)
{
    local int i;
    local OcclusionState State;
    local Color StateColor;

    for (i = 0; i < OcclusionStates.Length; i++)
    {
        State = OcclusionStates[i];

        // Color by occlusion level
        switch (State.Level)
        {
            case OL_None:    StateColor = GreenColor; break;
            case OL_Partial: StateColor = YellowColor; break;
            case OL_Heavy:   StateColor = OrangeColor; break;
            case OL_Full:    StateColor = RedColor; break;
        }

        // Draw actor bounds
        DrawDebugBox(State.TargetActor.Location,
                     State.TargetActor.CollisionRadius,
                     State.TargetActor.CollisionHeight,
                     StateColor);

        // Draw alpha value
        DrawDebugText(State.TargetActor.Location,
                      "A:" $ int(State.CurrentAlpha * 100) $ "%",
                      StateColor);
    }
}
// }}}
```

## Testing Requirements

### Visual Testing
- [ ] Transitions are smooth (no jarring pops)
- [ ] Ghost effect looks good on various textures
- [ ] No z-fighting or render order issues
- [ ] Consistent appearance across actor types
- [ ] Works with different lighting conditions

### Edge Case Testing
- [ ] Rapid camera movement doesn't cause flickering
- [ ] Overlapping occluders handled correctly
- [ ] Partial occlusion looks correct
- [ ] Very close geometry handled
- [ ] Very far geometry handled

### Style Testing
- [ ] All OcclusionStyle options work
- [ ] Configuration options apply correctly
- [ ] Default settings look good

## Related Documents
- docs/006-rendering-system-technical.md
- issues/701e-performance-optimization.md
- issues/701-dynamic-occlusion-system.md (parent)

## Acceptance Criteria

- [ ] Smooth fade transitions implemented
- [ ] No visual flickering or popping
- [ ] Partial occlusion handled gracefully
- [ ] Configuration options working
- [ ] Ghost/silhouette effect available
- [ ] Occluded unit indicators implemented
- [ ] Debug visualization enhanced
- [ ] All occlusion styles implemented
- [ ] Tested on 5+ maps
- [ ] User feedback incorporated (if available)

## Notes

This is the final polish pass. Don't implement until core functionality is working.

Visual polish is subjective. Get feedback from testers if possible.

Some effects may impact performance. Maintain the performance budget from 701e.

This issue may spawn additional sub-issues if specific visual features require significant work.

The goal is for occlusion to feel natural and intentional, not like a bug or limitation.
