---
name: independent input routing
phase: 2
status: pending
blockedBy: [201]
---

# 202 — independent input routing

Each panel's digitizer drives only its own emulator's cursor. Touches
on screen A go to instance A; touches on screen B go to instance B.
No cross-screen leakage.

## current behavior

Only screen A's digitizer is wired to its emulator's ADB mouse path
(issue 104). Screen B's digitizer is idle, even though instance B is
now running (issue 201).

## intended behavior

- The broker reads from **both** digitizer event devices simultaneously.
- Events from screen A's digitizer route to instance A; events from
  screen B's digitizer route to instance B. The routing is purely a
  function of which event device the event came from — not focus,
  not cursor position.
- Each emulator has its own cursor. The two cursors move
  independently and do not share state.
- The coordinate mapping (panel x/y → IIgs framebuffer x/y) is the
  same per-panel calculation from issue 104, applied independently to
  each side.
- A touch on screen A while the user's "focus" (issue 203) is on
  screen B does not move B's cursor. It moves A's, because that's
  the screen the user is touching. Focus governs sticks and buttons;
  touch always governs its own screen.

## suggested implementation steps

1. From issue 101's hardware probe, identify the `/dev/input/eventN`
   device for each panel's digitizer. Document the mapping in
   `docs/002-hardware-target.md`.
2. Extend the broker's input loop to read both event devices
   concurrently (epoll or two threads, depending on the broker's
   threading model).
3. Add a routing table mapping `input_device → emulator_instance`.
   Touches on device-A's stream go through the panel-A → IIgs-A
   coordinate mapping and into instance A's ADB mouse path; same
   for B.
4. Test the two-cursor case: touch screen A, see A's cursor move;
   then touch screen B, see B's cursor move, and confirm A's cursor
   has not changed position.
5. Test the stylus case: pen on A's panel moves A's cursor; same
   for B.

## related documents

- `docs/001-architecture-overview.md` — broker input routing
- `docs/003-input-system.md` — touch and stylus as mouse
- `issues/104-touch-as-mouse.md` — single-screen prerequisite
- `issues/201-second-emulator-instance.md` — provides instance B

## notes

- Two cursors that never share state is load-bearing: it preserves
  the "each screen is its own IIgs" architecture even at the input
  layer. Don't be tempted to add a "swipe to send cursor to other
  screen" feature; that breaks the model.
- If the RG DS exposes both digitizers through a single
  `/dev/input/eventN`, the broker disambiguates by inspecting which
  panel coordinate range the event falls into. Verify which model
  applies during issue 101.
