---
name: focus model
phase: 2
status: pending
blockedBy: [201, 202]
---

# 203 — focus model

A focus state tracks which screen is the "current" target for stick
and button input. The duplicated Start / Select pairs (one set per
screen) let the user explicitly switch focus. Touches and stylus
always route to their own screen and are not governed by focus.

## current behavior

Two emulators are running (issue 201) with independent touch routing
(issue 202), but no policy exists for where stick and button events
go. The hardware has duplicated Start / Select pairs but the broker
ignores them.

## intended behavior

- The broker holds a **focus state** = one of `{A, B}`, indicating
  which screen receives stick input, d-pad input, face buttons,
  shoulder buttons, and (eventually, phase 4) radial-keyboard
  character emissions.
- The duplicated Start / Select buttons mediate focus:
  - Pressing the **right-side Start** sets focus to A.
  - Pressing the **bottom-left Start** sets focus to B.
  - (Pressing the Start button for the *currently* focused screen
    does nothing to focus, but should still pass through to that
    emulator as an ordinary Start press if applicable.)
- The Select buttons (right-side and bottom-left) toggle the radial
  keyboard for the corresponding screen, independent of focus.
- A subtle visual indicator shows which screen has focus — for
  example, a thin colored border around the panel, or a small icon
  in the status strip. Not load-bearing; refine in phase 5.
- The focus state is the basis for the **last-input target** used by
  the radial keyboard (phase 4): when a character is emitted from
  the radial keyboard, it goes to the focused screen's last-input
  window/program triplet.
- Focus persists across overlay toggles, app launches, and emulator
  events. It only changes when the user explicitly presses Start,
  or when phase 4's "last-input target" rule overrides it via touch
  on the other screen.

## suggested implementation steps

1. Add a `focus` field to the broker's state, initialized to `A`.
2. Wire the right-side Start button to set `focus = A`; wire the
   bottom-left Start to set `focus = B`.
3. Route stick events, d-pad, face buttons, and shoulder buttons to
   `instance[focus]`'s ADB controller (until phase 8 liberates them).
4. Wire the right-side Select to toggle radial-keyboard activation
   for instance A; bottom-left Select toggles it for instance B.
5. Render a subtle focus indicator. For phase 2, this can be as
   simple as a 1-pixel border in a chosen color on the focused
   screen's letterbox area.
6. Test: user runs an app on each screen, switches focus with Start,
   observes that stick presses go to the focused screen only.

## related documents

- `docs/001-architecture-overview.md` — broker input routing and
  last-input target
- `docs/003-input-system.md` — buttons table, radial keyboard
- `issues/202-independent-input-routing.md` — touch routing (not
  governed by focus)

## known design questions

- Should "implicit focus change on touch" exist now, or wait until
  phase 4's last-input-target work? Argument for now: a user
  tapping on screen B almost always wants subsequent stick input to
  go there too. Argument for later: phase 4 introduces the
  three-element last-input triplet, which subsumes simple focus and
  may want to subsume the touch-changes-focus rule too. Default
  for phase 2: explicit Start-button focus only; implicit-on-touch
  arrives in phase 4.
- What about R3 (right-stick click)? It's a button — does it route
  by focus, or does it route by which stick was clicked? Probably
  by focus, since both sticks belong to "the focused screen" at
  this stage. Revisit in phase 4 if needed.
