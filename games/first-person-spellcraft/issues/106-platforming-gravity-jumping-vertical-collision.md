# 106 — Platforming: Gravity, Jumping & Vertical Collision

> **Phase:** 1 (Engine Foundation) · **Depends on:** `105` (adds a vertical axis
> to horizontal movement), `103` (per-cell floor/ceiling heights), `104a`
> (pitch/camera-z so verticality reads on screen) · **Blocks:** `107` and the
> Phase 4 platforming-puzzle seam · **Difficulty:** medium-hard · **Kind:**
> simulation system.

The vision explicitly asks for "platforming puzzles," so the engine needs a real
vertical axis: gravity that pulls you down, a jump that launches you up, and the
ability to land on and be stopped by the floor and ceiling heights the world
carries. Without this, Phase 4's platforming puzzles have nothing to stand on.

## Current Behavior

Nothing exists. The Player (issue `105`) moves horizontally but has no height, no
gravity, and no jump — the world is effectively flat to the player even though
the World data model (issue `103`) already stores per-cell floor and ceiling
heights and the renderer (issue `104`) can draw steps.

## Intended Behavior

A vertical axis layered onto the horizontal mover:

- **The Player's vertical state:** height above the world's zero (z), **vertical
  velocity**, and an **on-ground** flag. The renderer's Camera (issue `104a`)
  reads z + eye-height and pitch, so gaining height visibly raises the view.
- **Gravity.** Each fixed tick, gravity accelerates vertical velocity downward and
  integrates z, inside the same deterministic tick as horizontal movement (issue
  `105`) so jumps are repeatable.
- **Floor/ceiling collision.** After integrating z, clamp against the current
  cell's **floor height** (you land, vertical velocity zeroes, on-ground sets) and
  **ceiling height** (you bonk, downward velocity begins). The floor the player
  stands on is the floor height of the cell they're horizontally over — so
  stepping off a ledge means the floor beneath you drops and gravity takes you.
- **Jumping.** A jump intent (from the IntentFrame, issue `102`) launches the
  player upward **only when grounded**, giving vertical velocity a one-shot
  impulse. Jump strength and gravity are named constants tuned in
  `docs/balance-updates.md` — jump-arc feel is a knob turned often.
- **Step-up vs. must-jump.** Small floor-height increases can be auto-stepped
  (walk up a low lip) while larger ones require a jump — the threshold is a tuned
  constant. This is the raw material Phase 4 shapes into platforming puzzles: gaps
  you must clear, ledges you must reach.
- **Horizontal + vertical compose cleanly.** Vertical resolution runs after
  horizontal resolution (issue `105`) each tick, so walking off a ledge, jumping a
  gap, and landing all read correctly without the two systems fighting.
- **No fallbacks.** Falling below the world floor or through a missing floor value
  is a real error in the world data, surfaced loudly — not silently clamped to a
  safe height.

## Suggested Implementation Steps

1. Add the **vertical fields** (z, vertical velocity, on-ground) to the Player and
   spawn with feet on the spawn room's floor height.
2. Implement **gravity integration** in the fixed tick, after horizontal
   movement.
3. Implement **floor/ceiling clamping** against the current cell's heights: land
   and zero velocity on the floor, bonk and reverse at the ceiling, set the
   on-ground flag.
4. Implement **jump** (grounded-only impulse) from the jump intent.
5. Implement **auto step-up** for small lips and require a jump for larger rises,
   with a tuned threshold; record all vertical constants in
   `docs/balance-updates.md`.
6. Confirm the Camera (issue `104a`) reflects z + pitch so jumping visibly lifts
   the view, and prove platforming on the issue `103` test world's ledge: walk
   off it and fall, jump back onto it and land. Add a test that a jump from
   grounded rises then returns to the same floor height.

## Related Documents / Tools

- [datapath-engine-foundation.md](../docs/datapath-engine-foundation.md) — the
  Player vertical fields and the gravity/vertical transform.
- [notes/vision](../notes/vision) line ~118 — "have to do platforming puzzles."
- Depends on `105` (horizontal mover), `103` (heights), `104a` (camera z/pitch).
  Blocks `107` and Phase 4's platforming puzzles.
