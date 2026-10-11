# 307 — Phase 3 demo: a skirmish through the wheel

**Phase:** 3 — The wheel at the center
**Blocked by:** 301, 302, 303, 304, 305, 306, 108, 208

**Blocks**: 405
**Related documents:** docs/roadmap.md (Phase 3)

## Current Behavior

No phase 3 demo.

## Intended Behavior

A playable skirmish: one human seat with four stands against a scripted foe
in one direction, through the real console on phase 1's simulation. Live
statistics on the face: orders given, mean transit time, couriers in flight,
current reach and squeeze. On exit it prints the same statistics plus the
phase 1 determinism check over the recorded commands (replaying the human's
commands gives the same world).

## Suggested Implementation Steps

1. Demo settings file and script in `issues/completed/demos/`.
2. Command recording and replay check.
