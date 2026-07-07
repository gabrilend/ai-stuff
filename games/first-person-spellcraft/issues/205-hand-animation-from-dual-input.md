# 205 — Hand animation from dual input

> **Phase:** 2 — Dual-Mouse Aiming & Input
> **Difficulty:** medium
> **Depends on / blockers:** [202](202-per-hand-state-and-hand-role-assignment.md)
> (hand button/motion state), [204](204-dual-grip-aim-geometry.md) (the grip
> points to place the hands at), Phase 1 renderer
> ([datapath-engine-foundation.md](../docs/datapath-engine-foundation.md)) to draw
> them.
> **Blocks:** nothing hard downstream, but it is what makes the feature *visible*
> and feeds the per-hand pose channel that 206 exposes.

## Current Behavior

None of this exists yet — greenfield. The player would have aim but no visible
hands; the boomstick would be an invisible abstraction rather than "a thing you
hold, with two hands, and wave" (vision ~1-6).

## Intended Behavior

Both hands are drawn on the boomstick, **animated live from the two mice.** The
visual pose of each hand tracks its grip: the left hand sits at the left grip
point, the right hand at the right grip point (from 204), and the wand mesh
spans/points along the barrel line. Button state drives small poses — a finger
curl on press, a flick on fire — so the player *sees* their input land.

Critically, this issue produces a **per-hand pose channel**: a renderer-ready
description of both hands + the wand, decoupled from the mouse. Dual-mouse fills
it from real grips. Later, sources without two hands (gamepad, AI, BCI) fill the
same channel with a synthesized/idle pose so the hands still animate on screen
(see 206). This keeps the renderer ignorant of the input source.

## Suggested Implementation Steps

1. **Define the per-hand pose channel.** A small render-facing struct: left-hand
   pose, right-hand pose, wand orientation, and a few blend/gesture scalars (grip
   tightness, fire flick amount). Primitives and small structs, not a rig object.
2. **Drive poses from grips.** Place each hand's pose at its grip point from 204;
   orient the wand along the barrel line and by the roll. Turn button edges/holds
   into the gesture scalars (press → curl, fire edge → flick, ease back to rest).
3. **Smoothing.** Apply light easing/interpolation so raw per-tick jitter does not
   make the hands twitch (the dead-zone in 203 handles sensor noise; this handles
   visual smoothness). Keep the smoothing separate from the aim math — the aim
   (204) should stay crisp even if the *drawn* hands lag a hair for looks.
4. **Hand the pose to the Phase 1 renderer.** Register the pose channel as
   something the renderer reads each frame. This is a seam into Phase 1, not a new
   renderer — Phase 2 provides the poses, Phase 1 draws them.
5. **Rest / idle / holster poses.** Define what the hands do with no input (rest
   on the wand) so a still player still looks alive, and so non-dual sources have
   a sane pose to fill.
6. **Tests / visual check.** Assert the pose channel places hands at the grip
   points and raises the fire-flick scalar on a fire edge. A visual demo (part of
   the eventual phase demo) shows both hands tracking two mice live — per project
   convention the phase demo should *show the produced output*, e.g. a window with
   the two hands waving.

## Structures & Functions By Role

- A **per-hand pose channel** struct (left pose, right pose, wand orientation,
  gesture scalars).
- A **grips + buttons → poses** function (reads 204's aim result and 202's button
  state).
- A **smoothing/easing** helper for the drawn poses only.
- A **rest/idle pose** provider (also used as the fallback pose for non-dual
  sources).

## Design Notes To Record As Comments

- Why the pose channel is separate from the aim state: the renderer should read a
  *drawing* description, and downstream aim consumers should read a *direction*.
  Splitting them keeps a visual smoothing tweak from ever perturbing where a spell
  actually goes.
- Why non-dual sources reuse this channel: so the hands are always on screen no
  matter who is aiming (gamepad on the Anbernic, or an AI-controlled NCP).

## Related Documents / Tools

- Datapath: [datapath-dual-mouse-input.md](../docs/datapath-dual-mouse-input.md)
  — stage [5] per-hand pose channel and the Phase 1 renderer seam.
- Reads: [204 — dual-grip aim geometry](204-dual-grip-aim-geometry.md) and
  [202 — per-hand state](202-per-hand-state-and-hand-role-assignment.md).
- Exposed by: [206 — source-agnostic input abstraction layer](206-source-agnostic-input-abstraction-layer.md).
