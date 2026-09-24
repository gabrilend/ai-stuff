# Issue W05e: Body-Structure Fit Check and Body-Plan Standards

**Phase:** W - WoW Client Bridge
**Type:** Sub-issue of W05
**Priority:** Medium
**Dependencies:** W05d (the checker role), W03 (posing and rendering)

---

## Current Behavior

A replacement mesh for an animated creature is checked for overall size
(W05d) but not for whether its body is built so that the creature's animations
will work: a knight whose armour hides legs half the length of the skeleton's
legs will look broken when it walks, even at the right height.

## Intended Behavior

The owner (2026-09-23): "a system that looks at the mesh, its animation
skeleton, and the generated mesh. It attaches the animation skeleton, and then
poses them similarly, takes photos, and uses AI to estimate if the physical
body structure underneath the armor and such matches. If it does, then the
animations will work well. When we are creating our own animations, it will
benefit us quite a lot to be standardized on the same sets of dimensions that
the engine is designed to handle."

Two parts.

### 1. The fit check (a checker-role tool)

1. Take the original mesh with its skeleton, and the generated mesh.
2. Bind the skeleton to the generated mesh (nearest-vertex weights, as in W05b).
3. Put both into the same set of test poses (T-pose, walk mid-stride, attack
   wind-up, crouch/death), chosen to stress hips, knees, shoulders, elbows.
4. Photograph both from the fixed camera ring.
5. Measure per joint: does the generated mesh's joint sit where the
   skeleton's joint is (limb lengths, joint heights, shoulder width)? Then ask a
   vision model, per pose, whether the body under the armour bends where the
   skeleton bends (answer in a fixed shape: joint, fits/doesn't, confidence).
6. Output: a fit verdict per joint and per pose, plus the measurements.

Clean-room rule: this tool sees the original, so it is a **checker**. Only the
per-joint verdicts and measurements go back to the builder (e.g. "left knee
sits 0.2 yd above the skeleton's knee"), never the photos of the original.
That keeps W05d's separation intact.

### 2. Body-plan standards (the shared dimensions)

A **body plan** is a named set of functional dimensions the engine and future
animations are built around:

| Field | Type | Meaning |
|-------|------|---------|
| name | string | e.g. `humanoid-medium`, `humanoid-large`, `quadruped-medium`, `flyer-small` |
| height | float, yards | standing height |
| joints | list of (name, height fraction, side offset fraction) | where hips, knees, shoulders, elbows, neck sit, as fractions of height |
| limb lengths | list of (name, fraction of height) | upper/lower arm and leg |
| attachment points | list of (name, height fraction) | overhead, chest, hands, origin |
| footprint radius | float, yards | collision and selection |

Every replacement for an animated creature declares its body plan, and the
fit check measures against that plan. When custom skeletons and animations
are built later (a separate system, not designed yet), they target the same
plans, so any model made to a plan works with any animation made to that plan.

The first plans are measured from the existing skeletons, because those are
what the current animations need. That makes the first plans' numbers
`derived` facts. They are functional dimensions (where a knee is), not
appearance. Later plans can be defined from scratch.

## Suggested Implementation Steps

1. Body-plan file format and a measuring tool that proposes a plan from a skeleton.
2. Test pose set per plan family (biped, quadruped, flyer).
3. Pose-and-photograph both meshes (W03's renderer, offscreen).
4. Per-joint measurement; vision-model verdict in a fixed JSON shape (malformed answers are errors).
5. Feed verdicts, not photos, back into W05d's loop.
6. Tests: the original mesh checked against its own skeleton fits everywhere; a mesh with legs shortened by 30% fails at knees and hips.

## Acceptance Criteria

- [ ] Three body plans defined (humanoid-medium, humanoid-large, quadruped-medium)
- [ ] The self-fit and shortened-legs tests pass
- [ ] A W05d round receives per-joint verdicts and nothing else from this tool

## Open Questions

1. How many body plans should the engine support? Fewer plans mean more animation reuse; more plans mean better fits.
2. Should WC3's own unit data (model scale, selection scale, collision size) set the plans' footprint and height ranges, so plans match what WC3 maps expect?

## Related Documents

- `issues/W05d-clean-room-describe-build-check-loop.md`, `issues/W05b-borrowed-skeleton-and-animation-sets.md`
