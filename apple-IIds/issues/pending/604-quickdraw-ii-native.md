---
name: QuickDraw II native
phase: 6
status: pending (pending soramech)
blockedBy: [601, 602, 603]
---

# 604 — QuickDraw II native *(pending soramech)*

Replace the emulated QuickDraw II with a native ARM implementation.
The big one — QuickDraw is the largest of the Toolbox subsystems
and the one whose performance most affects the user experience.

## current behavior

QuickDraw II runs in emulation. Every line drawn, every rect
filled, every text glyph rendered executes 65C816 assembly. On a
2 GHz ARM A55 this is fast in absolute terms but slow relative to
what the same hardware could do natively.

## intended behavior

- A native QuickDraw II runs on its own thread under soramech.
- It implements the same API surface (drawing primitives, region
  manipulation, GrafPort management, palettes, blits).
- Calls into QuickDraw cross from emulated to native via the same
  pattern issues 601–603 establish.
- The 320×200 framebuffer is owned by native QuickDraw; the
  emulated IIds writes into it via memory-mapped operations that
  native QuickDraw observes.
- Native QuickDraw can also render at other resolutions — opening
  the door for IIds programs (eventually) to draw at 640×480 or
  native-panel resolutions. Per-application opt-in; default is
  320×200 for compatibility.
- **Pending soramech**: thread sync, region locking for
  multi-thread access to GrafPorts.

## suggested implementation steps

1. Wait for issues 601–603. QuickDraw rests on the patterns those
   establish.
2. Read GS/OS's QuickDraw II source thoroughly. This is a
   multi-week study task by itself.
3. Map the API: drawing primitives, region operations, blit calls,
   palette management.
4. Build a native QuickDraw II incrementally. The right order:
   - primitive draw operations (line, rect, polygon)
   - region manipulation (intersect, union, copy)
   - bitmap blits (the most performance-sensitive operations)
   - text rendering
   - palette / color table management
5. Test each subsystem against the emulated equivalent for pixel-
   exact equivalence. This is critical — IIds software depends on
   QuickDraw's exact behavior, including rounding details.
6. Performance-test: open Platinum Paint, drag a selection across
   a complex image, measure FPS. Should drop from O(emulated-FPS)
   to O(panel-refresh-FPS), i.e., 60 FPS solid.

## related documents

- `issues/601-scrap-manager-native.md` — pattern precedent
- `docs/001-architecture-overview.md` — the future seam mentions
  QuickDraw as the big one
- `docs/004-roadmap.md` — phase 6 entry

## known design questions

- Pixel-exact equivalence is a high bar. Some QuickDraw behaviors
  (like how lines are anti-aliased — though QuickDraw II didn't AA
  really; how endpoints are inclusive vs exclusive) are subtle. A
  comprehensive regression test suite is required.
- Native rendering at other resolutions opens new possibilities
  but risks breaking apps that hardcode 320×200. Keep it opt-in.
- Hardware acceleration: the RG DS has a Mali GPU. Should native
  QuickDraw use it? Default for phase 6: software rendering only,
  matching the IIds contract. The hardware-accel question is
  worth its own follow-up.

## notes

- This is by far the largest of the phase 6 issues. Easily a
  multi-month subproject. Worth splitting into sub-issues
  (604a, 604b, ...) once detailed planning begins.
- Successful completion of native QuickDraw II is one of the
  project's most visible wins — the device suddenly feels much
  faster.
