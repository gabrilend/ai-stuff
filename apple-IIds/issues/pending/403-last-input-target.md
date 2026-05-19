---
name: last-input target tracking
phase: 4
status: pending
blockedBy: [202, 203]
---

# 403 — last-input target tracking

The broker tracks a triplet (screen, window, program) representing
the most recently active input target. Newly emitted radial-keyboard
characters route there. The overlay (issue 402) appears on whichever
screen is *not* this target.

## current behavior

Issue 203 introduced a coarse focus state `{A, B}` driven by the
duplicated Start buttons. There is no window-level or program-level
tracking.

## intended behavior

- The broker maintains `last_input = {screen, window, program,
  timestamp}`.
- Updated on every user-originated input event:
  - touch / stylus on a panel → screen = that panel
  - press of a focused screen's Start button → screen = that panel
  - radial-keyboard character commit → screen unchanged (the
    target is who *is* receiving)
- The `window` and `program` fields are read from the active
  emulator. During phase 4, the broker can only see them through
  GS/OS-side observation — for example, by polling a small piece of
  state we inject into GS/OS (or by reading the active window's
  title from the Window Manager's data structures, which is fragile).
- Until issue 702 (Broker Input device) lands and gives us a cleaner
  read path, the screen-level field is reliable and the
  window/program fields may be empty strings during phase 4. This is
  acceptable — phase 4 characters route at the screen level only.
- The **inverse** of this state is the "active screen" for the
  overlay renderer (issue 402).
- The triplet is persisted across overlay toggles, app launches, and
  unrelated UI events. It changes only on real user input.

## suggested implementation steps

1. Add `last_input` to the broker's state with the four fields.
2. Hook into the input pipeline at the broker layer: every touch,
   stick, button press updates `last_input.screen` to the originating
   panel.
3. Update `last_input.timestamp` from a monotonic clock.
4. Wire the focus state from issue 203 to update `last_input.screen`
   when Start is pressed.
5. Expose a `get_last_input()` query for the overlay renderer and
   for the character-emission path (issue 404).
6. Stub `window` and `program` for now (empty strings); these get
   populated properly once issue 702 lands.

## related documents

- `docs/003-input-system.md` — last-input tracking section
- `docs/001-architecture-overview.md` — broker responsibility #4
- `issues/202-independent-input-routing.md` — touch-as-input
- `issues/203-focus-model.md` — Start-button focus toggle
- `issues/402-radial-overlay-renderer.md` — overlay placement
- `issues/702-broker-input-device.md` — eventual cleaner read path

## known design questions

- Should touch on a screen *also* change the broker-level focus
  (issue 203), or only the last-input target? Default for phase 4:
  yes, touch changes focus too. The "focus" and "last-input target
  screen" fields stay in sync. This is the "implicit focus change
  on touch" question deferred from issue 203.
- Tie-break when both screens have the same timestamp (vanishingly
  unlikely but theoretically possible): screen A wins by convention.
