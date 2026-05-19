---
name: input system
status: draft (design in flux, 2026-05-19)
---

# input system

Four input channels: **touch/stylus**, **buttons/d-pad**, the **radial
dual-stick keyboard**, and (later) the **gyroscope**.

## touch and stylus — the mouse

Tap = mouse-down + mouse-up at the touched coordinate.
Drag = mouse-down on touch-start, motion events while moving, mouse-up on
touch-end.

Both RG DS panels have multi-touch capacitive digitizers with stylus
support. A touch on screen A routes to emulator A; same for B. The mouse
cursor in each emulated IIgs follows that screen's most recent touch
position. There are conceptually **two cursors**, one per IIgs — never a
shared cursor that moves between screens.

GS/OS click targets (close-boxes, scroll arrows, menu items) are small.
**Finger tap is permissible but the stylus is recommended.** The digitizer
likely reports finger vs stylus separately (to be confirmed); if so:

- finger tap → ordinary click
- stylus tap → ordinary click
- finger-held + stylus tap → right-click equivalent (System 7-era control-click)
- or, alternatively: stylus-with-side-button → right-click

Long-press is reserved for a future right-click fallback if the digitizer
doesn't distinguish finger from stylus.

## buttons — modifiers and commands

| input            | function (provisional)                            |
|------------------|---------------------------------------------------|
| d-pad            | arrow keys (up/down/left/right)                   |
| A (face)         | confirm / mouse click (when stick-cursor mode)    |
| B (face)         | cancel / Escape                                   |
| X (face)         | space                                             |
| Y (face)         | return / enter                                    |
| L1               | shift (held)                                      |
| R1               | apple key / Command (held)                        |
| L2               | option (held)                                     |
| R2               | control (held)                                    |
| right-side Start | switch focus to screen A / toolkit menu on A      |
| right-side Select| toggle radial keyboard for screen A               |
| bot-left  Start  | switch focus to screen B / toolkit menu on B      |
| bot-left  Select | toggle radial keyboard for screen B               |
| L3 (left click)  | tab                                               |
| R3 (right click) | escape (also B duplicates this — TBD)             |
| volume up/down   | device volume                                     |
| power            | sleep / wake (Hall sensor handles lid-style sleep)|

The duplicated Start / Select pairs are the load-bearing piece: **each
screen has its own pair**, so neither screen has to share its menu/keyboard
shortcuts with the other. This mirrors the dual-desktop architecture at
the hardware level.

All bindings are provisional and will be revisited after the first
hardware test.

## the radial dual-stick keyboard

This is the centerpiece.

### the gesture

To type a character:

1. **Tilt the left stick** into a region. The bottom-screen overlay lights
   up that region's slice and renders the characters available there.
2. **While still holding the left stick**, tilt the right stick toward the
   desired character. The character is emitted on right-stick release (or
   on right-stick crossing into a clearly different wedge — TBD).
3. **Release the left stick** to dismiss the overlay.

Typing is **two-handed and gestural**, not button-mashing. Speed is slow
at first and improves with muscle memory.

### the grid

Each panel has a 4″ IPS digitizer and the sticks click as buttons, so the
total addressable character space can include modifiers from a stick-click.

| left wedges | right wedges | total cells | sufficient?                |
|-------------|--------------|-------------|----------------------------|
| 4           | 4            | 16          | no (alphabet alone needs 26) |
| 4           | 8            | 32          | yes for A–Z + a few        |
| 8           | 4            | 32          | yes for A–Z + a few        |
| 8           | 8            | 64          | yes for full printable ASCII |

Starting layout, optimistic 8 × 8 = 64 cells, downgrading individual
wedges to fewer sub-wedges if they prove unreliable:

- 4 wedges on the left, 8 on the right → 32 cells base
  - left-up: A–H
  - left-right: I–P
  - left-down: Q–X
  - left-left: Y, Z, and 6 punctuation slots
- Holding **L3** (left stick click) switches to a numeric / symbol layer
- Holding **R3** (right stick click) switches to a punctuation / shifted layer

If individual right-wedges prove hard to hit precisely, drop that left-
wedge to 4 right-sub-wedges and put the missing characters on the L3/R3
modifier layers.

### the overlay

When the left stick leaves its dead-zone, the bottom panel renders a
circular menu **on top of whatever the emulated IIgs was drawing there**.
Each wedge shows its characters in a readable font. The currently-selected
wedge (from the left stick's current direction) is highlighted; once the
right stick enters a wedge, that character is **further** highlighted.

Releasing the left stick fades the overlay out over ~150 ms. The emulated
IIgs's display is undisturbed underneath (the broker draws the overlay
as a separate compositor layer; it never touches the IIgs framebuffer).

### what the emulator sees

Once a character is committed, it enters the active emulator's keyboard
event queue as if a real keyboard had been pressed. The emulator has no
idea the radial keyboard exists; it sees an ordinary KeyDown / KeyUp pair
flowing through ADB (the IIgs's keyboard bus).

Once GS/OS is modified, we can shortcut this and inject events directly
into GS/OS's Event Manager queue, bypassing the ADB emulation entirely.
That's a phase 6+ optimization.

### accessibility

A "training mode" is planned where the overlay stays visible at all times,
even before the left stick is tilted, so a learner can see the full
layout. This is a setting in the broker, not in either emulator.

### tactile feedback

The RG DS has a vibration motor. Each successful character emission can
trigger a brief vibration pulse — a "click" you feel in your hands. This
is the kind of detail the original IIgs never had access to and is one
of the small ways the modernized port differs from the museum-piece
emulator.

### what is unresolved

- Exact wedge counts and character assignments — needs hardware-in-hand
  testing
- Commit-on-release vs commit-on-wedge-entry — needs feel testing
- Whether modifier keys (shift / command) are sticky-toggle or held —
  needs feel testing
- Whether L3/R3 click is the right gesture for modifier layers, or whether
  shoulder buttons make more sense
- Visual style of the overlay — needs assets

## gyroscope (later)

The RG DS has a six-axis gyro. Two potential uses:

- **Fine cursor mode.** Hold a shoulder button to lock the cursor to gyro
  control — small wrist motions move the pointer precisely, useful for
  pixel-art work or close-box hunting in GS/OS.
- **Screen rotation.** If the user holds the device sideways, swap the
  two screens' roles (the top becomes a wider single screen, or each
  panel becomes a portrait-oriented IIgs). Probably not in scope for a
  long time.
