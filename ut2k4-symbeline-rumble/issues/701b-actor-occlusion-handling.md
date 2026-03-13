# Issue 701b: Actor Occlusion Handling

## Status
- Phase: 7
- Priority: High
- Status: Open
- Dependencies: 701a-occlusion-detection-framework
- Parent Issue: 701-dynamic-occlusion-system

## Current Behavior

After Issue 701a, we can detect which actors occlude waypoints. However, those actors are not modified in any way - they continue to block the player's view.

## Intended Behavior

When an actor (StaticMesh, Mover, Decoration) is detected as occluding:
1. The actor's rendering is modified to make it transparent or hidden
2. The modification is proportional to occlusion severity (optional)
3. When the actor no longer occludes, it returns to normal rendering
4. Transitions are smooth, not jarring
5. Collision remains unaffected (gameplay intact)

## Actor Types to Handle

### StaticMeshes
- Most common occluder type
- Full control via actor properties
- Can modify: bHidden, Skins[], DrawScale, Style

### Movers
- Doors, lifts, platforms
- Technically BSP but manipulated as actors
- Similar control to StaticMeshes

### Decorations
- Smaller decorative objects
- Standard actor manipulation
- Usually low priority (small occlusion)

### Emitters/Effects
- Particle systems, visual effects
- Usually should NOT be hidden
- May need explicit ignore list

## Suggested Implementation Steps

### 1. Create Occlusion State Tracker

Track original state so we can restore it:

```unrealscript
// {{{ struct OcclusionState
struct OcclusionState
{
    var Actor TargetActor;
    var array<Material> OriginalSkins;
    var byte OriginalStyle;
    var bool bOriginalHidden;
    var float CurrentAlpha;      // For transitions
    var float TargetAlpha;       // Desired alpha
    var float OcclusionStartTime;
};
// }}}

var array<OcclusionState> OcclusionStates;
```

### 2. Implement State Management

```unrealscript
// {{{ function GetOrCreateState
function OcclusionState GetOrCreateState(Actor A)
{
    local int i;
    local OcclusionState NewState;

    // Find existing state
    for (i = 0; i < OcclusionStates.Length; i++)
    {
        if (OcclusionStates[i].TargetActor == A)
            return OcclusionStates[i];
    }

    // Create new state
    NewState.TargetActor = A;
    NewState.OriginalSkins = A.Skins;
    NewState.OriginalStyle = A.Style;
    NewState.bOriginalHidden = A.bHidden;
    NewState.CurrentAlpha = 1.0;
    NewState.TargetAlpha = 1.0;
    NewState.OcclusionStartTime = Level.TimeSeconds;

    OcclusionStates.AddItem(NewState);
    return NewState;
}
// }}}

// {{{ function RemoveState
function RemoveState(Actor A)
{
    local int i;

    for (i = OcclusionStates.Length - 1; i >= 0; i--)
    {
        if (OcclusionStates[i].TargetActor == A)
        {
            RestoreOriginalState(OcclusionStates[i]);
            OcclusionStates.Remove(i, 1);
            return;
        }
    }
}
// }}}
```

### 3. Implement Hiding Strategy (Simple)

Simplest approach - just hide occluders:

```unrealscript
// {{{ function ApplyHideOcclusion
function ApplyHideOcclusion(Actor A)
{
    local OcclusionState State;

    State = GetOrCreateState(A);
    State.TargetAlpha = 0.0;

    A.bHidden = true;
}
// }}}

// {{{ function RemoveHideOcclusion
function RemoveHideOcclusion(Actor A)
{
    local int i;

    for (i = 0; i < OcclusionStates.Length; i++)
    {
        if (OcclusionStates[i].TargetActor == A)
        {
            A.bHidden = OcclusionStates[i].bOriginalHidden;
            return;
        }
    }
}
// }}}
```

### 4. Implement Transparency Strategy (Advanced)

More sophisticated - make occluders semi-transparent:

```unrealscript
// {{{ var TransparentMaterials
// Pre-created transparent materials (or create at runtime)
var Material TransparentMaterial;
var array<Material> TransparentVersions;
// }}}

// {{{ function ApplyTransparencyOcclusion
function ApplyTransparencyOcclusion(Actor A, float Alpha)
{
    local OcclusionState State;
    local int i;
    local Material TransMat;

    State = GetOrCreateState(A);
    State.TargetAlpha = Alpha;

    // Create or get transparent material
    TransMat = GetTransparentMaterial(Alpha);

    // Apply to all skins
    for (i = 0; i < A.Skins.Length; i++)
    {
        // Store original if not already stored
        if (State.OriginalSkins.Length <= i)
            State.OriginalSkins[i] = A.Skins[i];

        A.Skins[i] = TransMat;
    }

    // Set render style for transparency
    A.Style = STY_Translucent;
}
// }}}

// {{{ function GetTransparentMaterial
function Material GetTransparentMaterial(float Alpha)
{
    local Shader TransShader;
    local ConstantColor AlphaColor;

    // Option 1: Use pre-made material
    if (TransparentMaterial != None)
        return TransparentMaterial;

    // Option 2: Create at runtime (may not work in all UE2 versions)
    // This is a simplified example - actual implementation may vary
    TransShader = new class'Shader';
    TransShader.Opacity = new class'ConstantColor';
    ConstantColor(TransShader.Opacity).Color.A = int(Alpha * 255);

    return TransShader;
}
// }}}
```

### 5. Implement Transition System

Smooth fade instead of instant pop:

```unrealscript
// {{{ function UpdateTransitions
function UpdateTransitions(float DeltaTime)
{
    local int i;
    local float FadeSpeed;
    local OcclusionState State;

    FadeSpeed = 4.0;  // Full transition in 0.25 seconds

    for (i = 0; i < OcclusionStates.Length; i++)
    {
        State = OcclusionStates[i];

        if (State.CurrentAlpha != State.TargetAlpha)
        {
            // Lerp toward target
            if (State.CurrentAlpha < State.TargetAlpha)
            {
                State.CurrentAlpha = FMin(State.CurrentAlpha + FadeSpeed * DeltaTime,
                                           State.TargetAlpha);
            }
            else
            {
                State.CurrentAlpha = FMax(State.CurrentAlpha - FadeSpeed * DeltaTime,
                                           State.TargetAlpha);
            }

            // Apply new alpha
            ApplyAlpha(State.TargetActor, State.CurrentAlpha);

            OcclusionStates[i] = State;
        }
    }
}
// }}}

// {{{ function ApplyAlpha
function ApplyAlpha(Actor A, float Alpha)
{
    if (Alpha <= 0.0)
    {
        A.bHidden = true;
    }
    else if (Alpha >= 1.0)
    {
        A.bHidden = false;
        A.Style = STY_Normal;
        // Restore original skins
    }
    else
    {
        A.bHidden = false;
        ApplyTransparencyOcclusion(A, Alpha);
    }
}
// }}}
```

### 6. Integrate with Detection Framework

Connect to the occlusion manager from 701a:

```unrealscript
// {{{ function NotifyOcclusionChanges
function NotifyOcclusionChanges(array<Actor> OldOccluders, array<Actor> NewOccluders)
{
    local int i;
    local Actor A;

    // Find actors no longer occluding (restore them)
    for (i = 0; i < OldOccluders.Length; i++)
    {
        A = OldOccluders[i];
        if (!IsInArray(A, NewOccluders))
        {
            // No longer occluding - fade back in
            SetOcclusionTarget(A, 1.0);
        }
    }

    // Find new occluders (hide them)
    for (i = 0; i < NewOccluders.Length; i++)
    {
        A = NewOccluders[i];
        if (!IsInArray(A, OldOccluders))
        {
            // Newly occluding - fade out
            SetOcclusionTarget(A, 0.3);  // 30% visible
        }
    }
}
// }}}

// {{{ function SetOcclusionTarget
function SetOcclusionTarget(Actor A, float Alpha)
{
    local OcclusionState State;

    State = GetOrCreateState(A);
    State.TargetAlpha = Alpha;

    // Update in array
    UpdateStateInArray(State);
}
// }}}
```

### 7. Handle Special Cases

```unrealscript
// {{{ function ShouldOcclude
function bool ShouldOcclude(Actor A)
{
    // Don't occlude if actor is important for gameplay
    if (A.IsA('Trigger'))
        return false;

    // Don't occlude special effects
    if (A.IsA('Emitter'))
        return false;

    // Don't occlude weapons/pickups
    if (A.IsA('Pickup'))
        return false;

    // Large static meshes - yes
    if (A.IsA('StaticMeshActor'))
        return true;

    // Movers - yes
    if (A.IsA('Mover'))
        return true;

    // Decorations - yes if large enough
    if (A.IsA('Decoration'))
        return A.CollisionRadius > 50;

    return false;
}
// }}}
```

### 8. Create Material Preloading System

Pre-create transparent materials to avoid runtime creation issues:

```unrealscript
// {{{ function PreloadTransparentMaterials
function PreloadTransparentMaterials()
{
    // Load pre-made transparent materials from package
    // These should be created in UnrealEd as translucent shaders

    TransparentMaterial25 = Material(DynamicLoadObject(
        "SymbelineRumble.Materials.Transparent25", class'Material'));
    TransparentMaterial50 = Material(DynamicLoadObject(
        "SymbelineRumble.Materials.Transparent50", class'Material'));
    TransparentMaterial75 = Material(DynamicLoadObject(
        "SymbelineRumble.Materials.Transparent75", class'Material'));
}
// }}}
```

### 9. Test and Document Behavior

Test on each actor type:
- [ ] StaticMeshActor
- [ ] InterpActor
- [ ] Mover
- [ ] Decoration
- [ ] BlockingVolume (should NOT be affected)
- [ ] KActor (Karma physics actors)

Document:
- Which actors work with transparency
- Which actors need hiding instead
- Any actors that cause issues

## Related Documents
- docs/006-rendering-system-technical.md (Strategy A, B sections)
- issues/701a-occlusion-detection-framework.md
- issues/701-dynamic-occlusion-system.md (parent)

## Technical Notes

### Render Styles
```
STY_None         - Invisible
STY_Normal       - Standard opaque
STY_Masked       - Binary transparency (texture alpha)
STY_Translucent  - Smooth transparency
STY_Modulated    - Multiplicative blending
STY_Alpha        - Alpha blending
STY_Additive     - Additive blending
STY_Subtractive  - Subtractive blending
```

### Material Considerations
- Skins[] array can be modified at runtime
- Shader materials can have Opacity channels
- ColorModifier can tint but not fade
- Some materials may not support transparency

### Performance
- Material swaps have cost - minimize per-frame changes
- Use state tracking to avoid redundant operations
- Batch material changes where possible

## Acceptance Criteria

- [ ] Can hide StaticMeshActors when occluding
- [ ] Can hide Movers when occluding
- [ ] Can hide Decorations when occluding
- [ ] Actors return to normal when no longer occluding
- [ ] Smooth transition (fade) between states
- [ ] Collision unaffected by visual changes
- [ ] No crashes or material errors
- [ ] Works on 3+ different maps
- [ ] Performance overhead acceptable
- [ ] Debug visualization shows state correctly

## Notes

This issue handles actor-based geometry only. BSP geometry (walls, ceilings built into the map) is handled separately in Issues 701c and 701d.

Start with the simple hiding strategy. Only implement transparency if hiding causes gameplay issues (players need to see occluded geometry shape).

The transition system is nice-to-have initially. Get basic functionality working first, then add smooth transitions.
