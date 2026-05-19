---
name: input system
status: draft (design in flux, 2026-05-19)
---

# input system

Four input channels: **touch/stylus**, **buttons/d-pad**, the **radial
dual-stick keyboard** (with two commit modes), and (later) the
**gyroscope**.

## touch and stylus — the mouse

Tap = mouse-down + mouse-up at the touched coordinate.
Drag = mouse-down on touch-start, motion events while moving, mouse-up
on touch-end.

Both RG DS panels have multi-touch capacitive digitizers with stylus
support. A touch on screen A routes to emulator A; same for B. The
mouse cursor in each emulated IIds follows that screen's most recent
touch position. There are conceptually **two cursors**, one per IIds —
never a shared cursor that moves between screens.

GS/OS click targets (close-boxes, scroll arrows, menu items) are
small. **Finger tap is permissible but the stylus is recommended.**
The digitizer likely reports finger vs stylus separately (to be
confirmed); if so:

- finger tap → ordinary click
- stylus tap → ordinary click
- finger-held + stylus tap → right-click equivalent (control-click)
- or: stylus-with-side-button → right-click

Long-press is reserved for a right-click fallback if the digitizer
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
| right-side Start | switch focus to screen A / Toolbox menu on A      |
| right-side Select| toggle radial keyboard for screen A               |
| bot-left  Start  | switch focus to screen B / Toolbox menu on B      |
| bot-left  Select | toggle radial keyboard for screen B               |
| L3 (left click)  | tab                                               |
| R3 (right click) | escape                                            |
| volume up/down   | device volume                                     |
| power            | sleep / wake (Hall sensor handles lid-style sleep)|

The duplicated Start / Select pairs are load-bearing: **each screen
has its own pair**, so neither screen has to share its menu/keyboard
shortcuts with the other.

All bindings are provisional and will be revisited after the first
hardware test.

## the radial dual-stick keyboard

This is the centerpiece.

### last-input tracking

The broker maintains a **last-input target**: which **screen**, which
**window** within that screen's GS/OS, and which **program** received
the most recent user input event. Newly emitted radial-keyboard
characters route to that triplet.

The triplet (screen, window, program) is updated on every input event:
a touch, a Start-button focus toggle, a character commit. It is read
on every character emission to decide where the character goes.

This matters because a user typing into a text field on screen A
shouldn't lose their place if they glance at screen B with a stylus
tap — but they *should* be able to switch focus deliberately via the
Start button without losing their cursor position within the current
window.

### the overlay lives on the *inactive* screen

When the left stick leaves its dead-zone, the **inactive** screen —
the one not currently the last-input target — renders the visual
radial menu. The active screen continues showing whatever was there,
undisturbed.

This is the reversal of the obvious-default ("overlay on the bottom
panel"): the overlay is on whichever screen you are *not* typing
into, so the document you're typing into is never obscured by the
keyboard guide.

When focus changes (Start button, deliberate touch on the other
screen), the overlay re-renders on the now-inactive screen. If the
user dismisses the overlay (releases the left stick) and then taps
into a new program, the *next* time they tilt the left stick the
overlay appears on whichever screen is freshly inactive.

If both screens have programs that just took input — possible during
cooperative pair-program work — the broker tie-breaks by
overlay-on-the-screen-with-fewer-recent-events, or the user can pin
the overlay to a chosen screen via a settings toggle.

### two commit modes

**Two-handed mode (the default).** Both thumbs on the sticks.

1. Tilt the **left stick** into a region. The radial menu on the
   inactive screen highlights that region and shows the characters
   available there.
2. Tilt the **right stick** toward the desired character. The
   character is emitted on right-stick release (or on right-stick
   crossing into a clearly different wedge — TBD).
3. Release the left stick to dismiss the overlay.

**One-handed mode** (stylus + left thumb). One hand holds the
device and the left thumb works the left stick; the other hand holds
the stylus.

1. Tilt the **left stick** into a region. The radial menu on the
   inactive screen highlights that region and shows the characters
   available there as visually-distinct touch targets.
2. **Tap the desired character with the stylus** on the inactive
   screen. The character is emitted.
3. Release the left stick to dismiss the overlay.

Both modes use the **same overlay**. The radial menu is always drawn
the same way; only the commit gesture changes. The broker accepts
input from whichever source arrives — stylus tap on a menu cell, or
right-stick wedge entry — and emits the corresponding character. The
two modes can be mixed within a single typing session.

### the grid

| left wedges | right wedges | total cells | sufficient?                |
|-------------|--------------|-------------|----------------------------|
| 4           | 4            | 16          | no (alphabet alone needs 26) |
| 4           | 8            | 32          | yes for A–Z + a few        |
| 8           | 4            | 32          | yes for A–Z + a few        |
| 8           | 8            | 64          | yes for full printable ASCII |

Starting layout: **8 × 8 = 64 cells**, downgrading individual wedges
to fewer sub-wedges if they prove unreliable in hardware testing.

A reasonable initial assignment (4-on-left × 8-on-right = 32 cells)
with the remaining 32 cells available via modifier layers:

- left-up: A–H (8 letters)
- left-right: I–P
- left-down: Q–X
- left-left: Y, Z, and 6 punctuation slots
- L3 held → numeric/symbol layer
- R3 held → punctuation/shifted layer

If a wedge proves hard to hit cleanly in practice (likely with 8 sub-
wedges), drop it to 4 and put the missing characters on the L3/R3
layers.

### the overlay's visual style

Not yet designed. Needs assets. Constraints:

- Must be readable at 320×200 effective resolution (the IIds native).
- Must be visible against arbitrary Super Hi-Res content underneath
  (high-contrast outlines, semi-transparent backdrop).
- Should highlight the **currently-selected** wedge (from the left
  stick's current direction) and **further-highlight** the cell the
  user is about to commit (right-stick wedge entry, or stylus hover
  if hover is detectable).
- Fade in over ~50 ms when the left stick leaves dead-zone; fade out
  over ~150 ms on left-stick release.
- In one-handed mode, the cells must be **at least as large as a
  comfortable stylus target** (provisionally 32×32 panel pixels);
  the radial geometry must accommodate this in its layout calc.

### what the emulator sees

Once a character is committed, the broker injects it into the active
emulator's keyboard event queue.

In the **staging-ground** architecture (phase 4), this is done via
emulated ADB — the radial keyboard pretends to be a real Apple
Keyboard talking on the ADB bus.

In the **post-input-liberation** architecture (phase 8), it goes
through the Broker Input device (issue 702) directly into GS/OS's
Event Manager, with no ADB layer involved. The emulated ADB remains
for compatibility with software that polls the keyboard hardware
directly.

### accessibility

A "training mode" is planned where the overlay stays visible at all
times, even before the left stick is tilted, on the inactive screen.
Useful for learners. This is a settings toggle in the broker, not in
either emulator.

### tactile feedback

The RG DS has a vibration motor. Each successful character emission
triggers a brief vibration pulse — a "click" you feel in your hands.
The original IIds never had access to this; it's one of the small
ways the modernized port differs from the museum-piece emulator.

### what is unresolved

- Exact wedge counts and character assignments — needs hardware-in-hand
  testing
- Commit-on-release vs commit-on-wedge-entry in two-handed mode —
  needs feel testing
- Whether modifier keys (shift / command) are sticky-toggle or held —
  needs feel testing
- Whether L3/R3 click is the right gesture for modifier layers, or
  whether shoulder buttons make more sense
- Tie-break rule when both screens have very recent input
- Visual style of the overlay — needs assets

## gyroscope (later)

The RG DS has a six-axis gyro. Two potential uses:

- **Fine cursor mode.** Hold a shoulder button to lock the cursor to
  gyro control — small wrist motions move the pointer precisely,
  useful for pixel-art work or close-box hunting in GS/OS.
- **Screen rotation.** If the user holds the device sideways, swap
  the two screens' roles. Probably not in scope for a long time.
