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

The chord-of box is multi-spawn-safe — multiple frames may be
in-flight in different workers; the ring buffer uses atomics and
the per-frame event set is captured by value at the time the box
fires, so an interleaved scan can't see a partial frame.

## Suggested implementation steps

1. `chord_of_box()` — generic two-button correlator.
2. Per-instance config (the two button names) on the box JSON.
3. Hook into the input-poll map from 501; specific chord
   instances added by 506.

## Related documents

- `docs/004-input-model.md` — the chord vocabulary section.

## Blocked by

502.

## Blocks

506, 508.
