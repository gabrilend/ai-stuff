# 204 — Rotating parts with weight and detents

**Phase:** 2 — Glass and metal
**Blocked by:** 202

**Blocks**: 205, 207, 208, 301
**Related documents:** docs/visual-language.md (Motion)

## Current Behavior

Shapes are static.

## Intended Behavior

- A rotor: angle, angular velocity, friction, and a list of detent angles.
  Dragging turns it directly; releasing lets it coast; near a detent it is
  pulled in and settles with a small overshoot.
- Scroll wheel steps one detent per notch.
- A rotor reports which detent is under a given fixed angle (the pointer
  notch), and fires one event when that changes (not every frame).
- Physics is framerate-independent (fixed sub-steps).

## Suggested Implementation Steps

1. `src/NNN-rotor.lua`: the rotor table and its step function. Pure numbers,
   no drawing.
2. Tests: a flick settles on a detent; settling is identical at 30 and 144
   frames per second; the change event fires once per detent crossed.
