# 105 — Player Movement & Wall Collision

> **Phase:** 1 (Engine Foundation) · **Depends on:** `102` (runs in the loop,
> reads the IntentFrame), `103` (collides against the tile grid) · **Blocks:**
> `106` (verticality builds on this), `107` (the demo walks around) ·
> **Difficulty:** medium · **Kind:** simulation system.

Getting around. This issue makes the Player move "semi-quickly" (the vision's
words) through a room and be *stopped by walls* — sliding along them rather than
sticking — all driven by normalized intents so Phase 2's two-mouse input can take
over later without rewiring anything.

## Current Behavior

Nothing exists. The Player structure isn't defined, no intent moves it, and there
is no collision — a would-be player would drift through walls, if there were a
player at all. The loop (issue `102`) currently runs a movement *stub*.

## Intended Behavior

Horizontal movement with wall collision, consuming intents not devices:

- **The Player's horizontal state:** position (x, y in tile units), facing angle
  (yaw), and horizontal velocity. Turning rotates yaw; forward/strafe intents
  push velocity along/across the facing.
- **Intent-driven, never device-driven.** Movement reads the **IntentFrame**
  (issue `102`) — move-forward, strafe, turn amounts — and nothing about mice or
  keys. This is the "aim once, aim everywhere" strategem's anchor: Phase 2 swaps
  what *fills* the IntentFrame; this system never notices.
- **Semi-quick feel.** Movement and turn speeds are tuned to feel brisk, as the
  vision asks. Speeds are named constants recorded in `docs/balance-updates.md`
  when tuned, not scattered magic numbers — brisk-but-not-twitchy is a knob we'll
  turn repeatedly.
- **Wall collision that slides.** After integrating position, resolve against
  solid cells (issue `103`) treating the player as a small radius/box, so walking
  into a wall at an angle **slides** along it instead of halting dead. Resolve
  each axis separately so a diagonal into a corner still slides along whichever
  wall it can.
- **Determinism.** Movement and collision run inside the fixed-timestep tick
  (issue `102`), so behaviour is frame-rate-independent — the same inputs produce
  the same motion on a fast dev machine and a struggling handheld.
- **Doors are passable, walls are not.** A door cell (issue `103`) that is
  currently passable lets the player through into the next room; a closed door
  collides like a wall. The room's enter/exit callbacks (the dispatch table from
  `103`) fire as the player crosses between rooms, so later phases can react.
- **No fallbacks.** If a collision query hits an out-of-bounds cell, that is a
  real error (the world should be walled), surfaced loudly — not clamped away
  silently.

## Suggested Implementation Steps

1. Define the **Player** horizontal fields (position, yaw, horizontal velocity)
   and a spawn that places the player in the world's spawn room.
2. Implement **intent → velocity**: turn intent rotates yaw; move/strafe intents
   set velocity relative to facing; apply the semi-quick speed constants.
3. Integrate position over the fixed tick.
4. Implement **axis-separated wall collision** against the tile grid with a small
   player radius, so walls stop and slide rather than stick; handle passable vs.
   closed doors.
5. Fire the room **enter/exit callbacks** as the player crosses room boundaries.
6. Replace issue `102`'s movement stub with this system; prove it by walking the
   test world — brisk motion, walls that slide, doors that pass — and record the
   chosen speeds in `docs/balance-updates.md`. Add a small test that a straight
   push into a wall ends with the player stopped at the wall, not through it.

## Related Documents / Tools

- [datapath-engine-foundation.md](../docs/datapath-engine-foundation.md) — the
  Player structure, the IntentFrame seam, the movement+collision transform.
- [notes/vision](../notes/vision) line ~117 — characters "move around
  semi-quickly."
- Depends on `102` (loop + IntentFrame) and `103` (grid + doors). Blocks `106`
  (adds the vertical axis) and `107` (the demo).
