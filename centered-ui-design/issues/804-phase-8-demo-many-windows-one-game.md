# 804 — Phase 8 demo: many windows, one game

**Phase:** 8 — Across the wire
**Blocked by:** 801, 802, 803, 708
**Related documents:** docs/roadmap.md (Phase 8)

## Current Behavior

No phase 8 demo.

## Intended Behavior

Launches two to four game windows on one machine (or accepts remote joins),
seats them through the lobby, and plays a full game with every feature of
phases 1–7. Each window shows live round-trip time, input delay in ticks,
and a checksum-agreement readout that ticks up with every agreed check.

## Suggested Implementation Steps

1. Launcher script opening N instances with distinct seats.
2. Network statistics readouts on the face.
