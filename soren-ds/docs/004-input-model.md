# Input model

The device has more input surfaces than most handhelds: two touch
screens, a D-pad, six face buttons (ABXY plus L and R), four
center buttons (`[start1][select1][select2][start2]` across the
bottom of the lower screen), two clickable analog sticks. This
document describes how those raw surfaces become events that apps
can subscribe to.

## Polling, not interrupts

Every 60th of a second, a single kernel thread reads the state of
every input surface from the hardware and compares it to the
previous frame's state. Anything that changed becomes an event
emitted on a soramech wire. This frame-rate matches the screen
refresh, gives at most one frame of input latency, and avoids the
complexity of interrupt-context code.

Interrupts are reserved for one job: waking the device from deep
sleep when a button is pressed. Once awake, the system polls.

## Buttons as boxes

Each button surface (each face button, each D-pad direction, each
trigger, each center button, each stick click) is exposed as two
event boxes: a *button-down* box that fires when the button
transitions from released to pressed, and a *button-up* box that
fires when it transitions back. The button-up box carries the
total duration the button was held, in milliseconds, as an output
value.

While a button is held, an optional *button-held* box can fire
once per polling frame. Apps that want a held-button effect — a
repeating cursor move, a draw-while-pressed paint stroke — wire to
the held box. Apps that don't care just leave that wire dangling.

Each of the three gives at most one event per frame, naming every
button it is about at once: five buttons pressed in the same frame are
one *button-down* event, which is what the chord detector wants. A frame
where nothing went down gives no *button-down* event at all. Each box
also takes the set of buttons to listen for, so an app that only cares
about the triggers wires to a box that only ever speaks of them. The
order of the buttons in that set is
`notes/diagnostics/001-button-bit-order.md`.

## The two touch screens

Both screens report stylus or finger position when touched. A
touch on either screen emits *touch-down*, *touch-move*, and
*touch-up* events, with the screen ID and the position attached.
There is no multi-touch — one cursor at a time per screen,
matching the device's intended use with a single stylus or finger.

## The four center buttons open drawers

The center buttons across the bottom of the lower screen are
single-button inputs. Pressing one opens a *drawer* — an overlay
menu that slides in from the left or right edge of a screen.
Pressing the same button again, or pressing any cancel input,
closes it. The default mapping:

```
button     drawer
─────────  ────────────────────
start1     bottom screen, left
select1    bottom screen, right
select2    top screen, left
start2     top screen, right
```

An option in the system menu swaps which physical pair drives
which screen: with the swap on, `start1`/`select1` open the top
screen's drawers and `start2`/`select2` open the bottom screen's.
Within each pair, the left button always opens the left drawer and
the right button always opens the right drawer.

The drawer's contents are owned by whichever app currently has
that screen's foreground. Most drawers present their options as a
small radial interface, the same input mechanism used for text
entry below.

## Inter-app linkage replaces app switching

There is no app switcher. There is no back button either. Apps
reach each other through *links*, and the user only ever moves
forward.

Every app exposes a small set of named exits in its drawers and in
other natural spots in its UI — "send this to messenger," "open in
editor," "save and view in files." Each exit declares the app it
goes to and the value it carries forward. Following an exit is
the navigation primitive of the system. The foreground app on the
screen where the exit was triggered changes to the linked app; the
linked app receives the carried value and the name of the app that
sent it.

Returning to a previous app is not a separate mechanic. It is
another exit, exposed by the destination app, that happens to go
to the app the user came from. The paint program exposes a "to
messenger (image)" exit; the messenger exposes a "to paint
(image-request)" exit; together they form a doubly-linked pair
the user walks across in both directions. Apps that need a round
trip build that round trip explicitly out of two forward links.

Background apps keep their state. When a link returns the user
to an app they were in earlier, that app comes back to the
foreground with the state it had when the user left it. There is
no history stack, no ring buffer, no path-tracking — only forward
links and persistent app state.

## The chord vocabulary

A *chord* is two or more buttons pressed together within the same
polling frame — or, for thumbs that rarely land inside one 16.7 ms
frame, within a few frames of each other: each chord names its own
window, and a window of 0 is the same frame only. Chords remain a first-class event in the kernel
because the radial menu chord drives text entry. They are no
longer used for navigation between apps.

The *radial menu chord*: a D-pad direction selects a quadrant; a
face button press picks the specific character. The chord delivers
both the direction and the face button as a single event so the
consuming box doesn't have to correlate two streams.

The D-pad reports **eight** directions, not four — straight and
diagonal both count. The user learns this as the first thing they
learn about typing on the device. Eight directions × four face
buttons gives thirty-two characters per mode, enough for the
alphabet, digits, and most punctuation in two or three modes
total. The L and R triggers switch between modes; with two
triggers per side, four or more modes are available without
scrolling.

The analog sticks also report eight directions and can chord with
the face buttons the same way. Sticks and D-pad cover the same
input space; the user picks whichever feels better in the moment.

How it is struck (issue 506): the direction is pushed first and held —
that is what brings the menu up — and every press of a face button
while it is held types one character, so a doubled letter is one push
and two taps. A face button pressed with no direction held, or two face
buttons at once, types nothing. The table of characters and which
trigger chooses which mode are written in
`src/maps/radial-menu-chord.map`; a user's own table replaces them
while the program runs.

## Handedness

The device supports right-handed and left-handed users by
remapping which side of the device controls navigation and which
controls action. There is a single setting — handedness — that
flips the roles:

- **Right-handed (default):** D-pad and left stick navigate, L
  triggers modify, ABXY and right stick act, R triggers modify
  on the action side.
- **Left-handed:** ABXY and right stick navigate, R triggers
  modify, D-pad and left stick act, L triggers modify on the
  action side.

The radial menu chord keeps its physical button identity (D-pad
direction plus face button, always), but the *meaning* of each
side in each app is interpreted through the handedness setting.
The paint program is the clearest example: in right-handed mode
the D-pad and L triggers select tools while the stylus on the
touch screens applies paint; in left-handed mode the ABXY and R
triggers select tools while the stylus still applies paint on
either screen.

Every input event names physical buttons; the meaning is a second
tag beside them, never in their place. In `input-poll` each button
down and up, and each stick change, passes an applier
(`src/boxes/134-input-roles.c`) that adds which of its buttons
navigate, which act, which modify each side, and which drawer its
center buttons open, under the handedness and drawer-swap settings
as they stand. An app that cares which button it was listens to the
raw events; one that cares what the button is for listens to the
applier's. The settings reach the appliers through
`input_settings_set` (`src/system/135-input-settings.h`), each event
seeing them wholly before or wholly after a change.
