# 202 — Per-hand state and hand-role assignment

> **Phase:** 2 — Dual-Mouse Aiming & Input
> **Difficulty:** medium
> **Depends on / blockers:** [201a](201a-discover-and-open-two-distinct-mice.md)
> (device identity + left/right tags), [201b](201b-per-device-evdev-read-loop.md)
> (per-device tick accumulators).
> **Blocks:** 203 (calibration refines this), 204 (geometry reads this), 205
> (animation reads this).

## Current Behavior

None of this exists yet — greenfield. The layers below produce **device-flavored**
data: "device on node event5 moved (dx, dy)." Nothing yet says "the LEFT HAND
moved," and nothing holds a hand's ongoing state between ticks.

## Intended Behavior

This is the layer where "device" becomes "hand." It does two jobs:

1. **Hand-role assignment.** Bind exactly one device to the **left hand** and one
   to the **right hand**, using the stable distinguishing key from 201a so the
   binding survives a replug or reboot. The assignment is explicit and persisted —
   never guessed. If it is missing, the interactive "wiggle your left-hand mouse"
   flow from 201a establishes it; the game does not silently pick one.

2. **Per-hand state accumulation.** Fold each tick's per-device delta into a
   persistent **hand state**: the hand's current grip position/orientation on its
   input surface, plus current button state (held vs just-changed). A mouse
   reports *relative* motion, so the hand's absolute grip pose is the running sum
   of deltas since the last re-center — this layer owns that integral.

The two hand states (left, right) are the single source of truth the aim geometry
(204) and the hand animation (205) both read.

## Suggested Implementation Steps

1. **Define the hand-state record.** Fields for grip pose (a 2D position, or a
   yaw/pitch pair — whichever the geometry in 204 settles on; keep it a small
   struct of primitives, not a framework object), accumulated since last
   re-center; button state (held set + this-tick edges); and a back-reference to
   which device feeds it.
2. **Define the role binding.** A tiny persisted map: left-hand → device key,
   right-hand → device key. Load it at startup; if absent or unresolved against
   the current candidate list, trigger the interactive assignment from 201a.
   Treat an unresolved binding as an error state to resolve, not a nil to paper
   over.
3. **Integrate deltas into pose.** Each tick, add the device accumulator's (dx,
   dy) (post-calibration once 203 lands) into the hand's grip pose. Apply the
   button edges into the hand's button state.
4. **Re-center support.** Expose a "re-center this hand" operation that zeroes the
   accumulated grip pose (used by calibration 203 and by a rest/holster action).
   Because motion is relative, without a re-center the grip pose would drift
   forever in one direction — this is the drift bound.
5. **Swap-hands operation.** A convenience to exchange the left/right bindings
   (left-handed players, or if the physical mice ended up reversed). It rewrites
   the persisted map, not the device streams.
6. **Test with synthetic accumulators.** Feed hand-authored per-device tick
   accumulators and assert the resulting hand poses — no hardware needed, since
   this layer is pure arithmetic over its inputs.

## Structures & Functions By Role

- A **hand state** record (grip pose, button state, feeding-device reference) — two
  instances, left and right.
- A **role binding** map (hand → stable device key) with load/save.
- An **integrate tick into hand** function (per hand).
- A **re-center hand** function and a **swap hands** function.

## Design Notes To Record As Comments

- Why a running integral: mice speak *relative* deltas; a hand's absolute grip
  pose only exists as the sum of deltas since a known zero. The re-center defines
  that zero. This is the single most important thing to remember when touching
  this file.
- Why explicit role binding: two identical mice are the common case, so "which is
  left" cannot be inferred from the model name; it comes from the physical
  port/path key or from the player wiggling the intended hand.

## Related Documents / Tools

- Datapath: [datapath-dual-mouse-input.md](../docs/datapath-dual-mouse-input.md)
  — stage [3] "per-hand state."
- Refined by: [203 — per-device calibration and sensitivity](203-per-device-calibration-and-sensitivity.md).
- Read by: [204 — dual-grip aim geometry](204-dual-grip-aim-geometry.md) and
  [205 — hand animation from dual input](205-hand-animation-from-dual-input.md).
