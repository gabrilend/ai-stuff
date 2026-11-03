# 505 — Chord detection

## Current behavior

The button event boxes from 502 emit one event per button per
transition. The radial menu input (506) needs to know about
two-button combinations (a D-pad direction *and* a face button)
that fire in the same polling frame. Without a chord detector
each chord-consuming map has to re-correlate two streams itself,
which is wasteful repeated work.

## Intended behavior

A `chord-of` box family emits a single event when two named
buttons go down in the same polling frame. The map-author
specifies which two buttons by name when the box is wired:

```
chord-of(button-down, "dpad-up", "abxy-a") → emits event when both
```

Internally, the chord-of box keeps a small ring buffer of the
last few frames' button-down events. Each fire of the chord-of's
input wire is one frame's events. The box scans for both named
buttons in the current frame's set and emits the combined event
when both are present.

The general two-button chord-of is the foundation. The radial
menu chord box (506) is built directly on top — its specific
combination is "any of eight D-pad directions" plus "any of four
face buttons," which the radial-menu box decomposes into a 32-way
event.

Multi-button chords (three or more in the same frame) are not in
scope at launch; the launch system has no three-button chord
anywhere. If a future feature needs one, the same `chord-of`
shape generalises.

Two cores may be inside the chord box at once, for adjacent frames, so
it keeps nothing: the window of recent frames arrives as one value on
one wire and leaves as one value on one wire.

**One value, because the frames in a window must stay together.** Two
values arriving at two ports of a station are not a pair — the engine
pairs whatever is at the head of each port, in whatever order the cores
produced them. Anything that must arrive as a unit is a single struct
on a single port, which is what the window is.

## Suggested implementation steps

1. `chord_of_box()` — generic two-button correlator.
2. Per-instance config (the two button names) on the box JSON.
3. Hook into the input-poll map from 501; specific chord
   instances added by 506.

## Open questions

- *Same frame, or a few frames?* The docs say "within the same polling
  frame"; two thumbs rarely land inside the same 16.7 ms.
- *Does it need the ring of past frames the steps describe?*
- *What does it read: the down events, or the history?*
- *How are the two buttons named on the box?* "Per-instance config on
  the box JSON" — maps are text now, and a fixed value is how a station
  is configured.
- *Does order matter?*
- *What if a name is not a button?*
- *When does the event fire, and how often?*

### Proposed answers (UNVERIFIED)

Each one is a choice Ritz can overturn.

1. *A window of frames, per chord.* The fixed value carries a window: 0
   means the same frame only, as the docs define it; 3 (50 ms) is a
   comfortable chord for thumbs. The radial menu (506) picks its own.
2. *No ring.* The button history (502) already holds the frame each
   button went down, so "how far apart did these two go down" is a
   subtraction, and chord_of keeps nothing and carries no loop of its own.
   The one-value-on-one-wire rule holds: the history is one struct on one
   port.
3. *The history,* for the reason above. It hangs off the same `buttons`
   station as button-down, -up and -held.
4. *By name, in a fixed value*: `{ "dpad-up", "abxy-a", 3 }`, using the
   names of `notes/diagnostics/001-button-bit-order.md`. Names read
   better in a map than bit numbers, and checking eighteen names twice a
   frame is nothing.
5. *No.* Either button may go down first.
6. *The station refuses on its first frame* (detail 1 or 2 says which
   name; 3 is the same button twice; 4 a negative window), which takes it
   out of service where the person can see why. A map cannot be checked
   for this at load time, because the loader knows the value's type, not
   what a box will make of it.
7. *Once,* on the frame the second button goes down, with both still
   held, carrying the frame, the two buttons and how many frames apart
   they went down. Holding both fires nothing more; letting one go and
   striking it again inside the window is a new chord.

Three-button chords stay out of scope, as the issue says.

## What happened

Built on the twin as answered above.

- `src/boxes/095-input.c` — `struct chord`, `struct chord_event` (16
  bytes, ordered by its buttons, so a comparator against `{ 0, 0, 0 }`
  lets only chords out), `chord_of`, and `say_chord` for the developer
  line.
- The input-poll map gets no chord of its own: which chords exist is the
  radial menu's business (506) and the apps'. A map adds one as a
  comparator on `buttons.0`.
- `twin/tests/102-test-chords.c` (12 checks): up then A a frame apart,
  A then up three apart, and both in one frame are chords; holding,
  four apart, and up let go before A are not; a window of 0 takes the
  same frame only; a misspelled name takes its station out of service
  saying which name.

## Related documents

- `docs/004-input-model.md` — the chord vocabulary section.

## Blocked by

502.

## Blocks

506, 508.
