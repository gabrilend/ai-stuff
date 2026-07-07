# 204 — Dual-grip aim geometry

> **Phase:** 2 — Dual-Mouse Aiming & Input
> **Difficulty:** medium (the math is small; getting the *feel* right is the work)
> **Depends on / blockers:** [202](202-per-hand-state-and-hand-role-assignment.md)
> (two hand states), [203](203-per-device-calibration-and-sensitivity.md) (matched
> feel between the hands).
> **Blocks:** 205 (animation shares this pose), 206 (the aim state wraps this
> result).

## Current Behavior

None of this exists yet — greenfield. Two hand states exist, but nothing turns
"where the two hands are" into "where the boomstick points." Without this, there
is no aim.

## Intended Behavior

The two hands grip a wand (a "boomstick" — a jax-style musketball / directional
wand). Like holding a rifle or a wand at two points, the **geometry of the two
grips is the aim.** This issue defines the one combining rule that turns two hand
poses into a single **aim result**: a direction (and a roll/twist), expressed in
the player's local aim space so it survives the player turning their body.

**Primary model — the two-point barrel line.** Treat each hand as a grip point in
the player's local aim space in front of them. The **aim direction** is the
normalized vector from the rear grip to the front grip (sighting down the barrel
the two grips define). Moving one hand up/left swings the muzzle the way you'd
expect from swinging that end of a real wand. The **roll/twist** of the boomstick
comes from the relative vertical (or lateral) offset between the two hands —
raising one hand rolls the wand — which later lets spells care about wand
orientation, not just where it points.

**Alternate model — base + brace (documented, second choice).** One hand (the
dominant/rear) sets a base yaw+pitch directly; the other hand applies a smaller
*differential* that braces/fine-tunes the base aim. Cheaper and steadier, less
physically expressive. Noted here so the choice is on the record; the primary
barrel-line model ships first. Per the convention that added modes must both be
proven working before being called complete, if the base+brace model is later
built it gets its own tests and a selectable toggle — until then it is documented
intent, not a half-wired branch.

The result is **pure geometry**: same two hand poses in, same aim out, every
time. It holds no state, so it is testable with hand-authored grip inputs and no
hardware.

## Suggested Implementation Steps

1. **Fix the aim space.** Decide and document the coordinate frame the grips live
   in (player-local, +forward down the aim, so turning the player does not move
   the aim relative to the wand). Comment this — every later reader needs it.
2. **Map grip pose → grip point.** Turn each hand's accumulated 2D grip pose into
   a 3D grip point in aim space (e.g. hand X/Y offsets the grip on a plane a fixed
   reach in front of the player). Front vs rear grip is set by the hand roles from
   202.
3. **Compute the barrel line.** Aim direction = normalize(front grip − rear grip).
   Guard the degenerate case (grips coincident) explicitly — if it can happen,
   find *why* and clamp the minimum separation, rather than nil-checking the
   normalize. A wand with zero length is a real design question, not a null.
4. **Compute roll.** Derive the twist from the relative offset between the hands;
   define its zero and its sign, and comment them.
5. **Emit the aim result.** A small struct: aim direction (unit vector, or
   yaw/pitch), roll angle, and the two grip points (so 205 can draw the hands
   exactly where the geometry placed them). Player-local; 206 composes it with the
   player's facing to reach world space.
6. **Tests.** Hand-author grip pairs and assert directions: hands level and
   centered → straight ahead; front hand raised → muzzle up; front hand left →
   muzzle left; one hand raised → expected roll sign. These tests are the
   specification of "feels right," so write them as the behavior is decided.

## Structures & Functions By Role

- An **aim result** struct: direction (unit vector or yaw/pitch), roll angle, the
  two grip points, all player-local.
- A pure **combine grips → aim** function (primary barrel-line model).
- A **grip pose → grip point** mapping helper.
- (Deferred) an alternate **base + brace** combine function, behind a mode
  selector, only if/when it is built and tested.

## Design Notes To Record As Comments

- Why player-local: keeps aim attached to the wand, not the world, so the same
  hand motion aims the same way regardless of which direction the player faces.
  206 is where local aim meets world facing.
- Why the barrel-line model is primary: it is the most physically honest to "two
  hands on one wand," which is the vision's whole conceit.

## Related Documents / Tools

- Datapath: [datapath-dual-mouse-input.md](../docs/datapath-dual-mouse-input.md)
  — stage [4] "dual-grip aim geometry."
- Reads: [202 — per-hand state](202-per-hand-state-and-hand-role-assignment.md).
- Feeds: [205 — hand animation](205-hand-animation-from-dual-input.md) and
  [206 — source-agnostic input abstraction layer](206-source-agnostic-input-abstraction-layer.md).
