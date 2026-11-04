# 204 — Dials that turn with weight

**Phase:** 2 — Glass and metal
**Blocked by:** 202
**Blocks**: 205, 207, 208
**Related documents:** docs/visual-language.md (Motion),
docs/datapath-glass-and-metal.md (dial)

## Current Behavior

Shapes are static.

## Intended Behavior

- A **dial** is the generic information component: a disc no thicker than
  paper, inscribed with a list of words or numbers around its edge, seen only
  through a seamless glass window cut into the surface above it.
- The game gives a dial a target (an inscription index); the dial turns there
  with weight — angular velocity, friction, settling at the inscription with a
  small overshoot. It never jumps.
- The player never turns a dial. Dials ignore all mouse and keyboard input.
- Physics is framerate-independent (fixed sub-steps).

## Suggested Implementation Steps

1. `src/NNN-dial-motion.lua`: angle, velocity, target, step function. Pure
   numbers, no drawing.
2. `src/NNN-dial.lua`: inscriptions, window shape, drawing (paper-thin disc
   under glass).
3. Tests: a new target is reached and settled; settling is identical at 30
   and 144 frames per second; mouse events never change a dial.
