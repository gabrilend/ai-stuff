# 506 — Radial menu chord box

## Current behavior

The chord detector (505) provides the generic two-button
mechanism but does not yet have the specific instance that the
text editor and the apps' drawers use for text entry. The
radial menu's "D-pad direction (or stick direction, eight ways)
plus face button (four ways)" combinatoric is the central input
the editor depends on.

## Intended behavior

A `radial-menu-chord` box emits a single event encoding the
specific chord struck:

- The direction component (one of 8): pulled from the
  `stick-direction-changed` or `button-down` (D-pad) streams via
  a configurable input port.
- The face button (one of 4): A, B, X, Y.
- The mode (one of N): determined by which combination of L1,
  L2, R1, R2 was held at the moment of the chord.

The output value is a single character (or character-equivalent
small struct) — the cell at row=direction × column=button × mode
in the editor's lookup table. The default lookup table covers
the alphabet, digits, and common punctuation across two or three
modes; the table itself lives in a configuration file the editor
loads from `/settings/` so the user can remap it.

The box is internally a small composition: chord-of (from 505)
applied to (any of eight directions) and (any of four face
buttons), gated by which mode triggers are held, looking up the
result in the table. The composition is itself a map fragment
that lives at `/system-maps/radial-menu-chord.json` on the SD
card; phase 8's editor wires it into its input pipeline.

The handedness setting (507) does not affect the radial menu
chord — the chord keeps its physical button identity. What
changes per-handedness is which side the user thinks of as their
direction hand and their action hand, but the radial menu's
mechanism is "one button from each hand" regardless.

## Suggested implementation steps

1. `radial_menu_chord_box()` — composite of chord-of plus mode
   gating plus table lookup.
2. The default lookup table at
   `/system-maps/radial-menu-table-default.json`.
3. Hooks for the editor (phase 8) to override the table per user
   setting.

## Decisions (2026-11-05)

Each one is a choice Ritz can overturn. Where the owner's own words
answer a question, they win over this issue's wording.

1. **The direction is held, and each face press types one character.**
   The vision note says it: "push the D-pad in a direction and it shows
   a circular menu which has 4 characters that you can type by pushing
   one of the AB/XY buttons." So this is not chord-of's window (505):
   the direction comes first and stays held, and every press of A, B, X
   or Y while it is held types one character ("ll" is one push and two
   taps). A direction pushed while a face button is already down types
   nothing, so the order is always direction, then button. Two face
   buttons going down in one frame type nothing.
2. **It reuses 505's idea, not its box.** One `chord_of` station per
   pair would be thirty-two stations, each with a window that does not
   fit decision 1. Instead `radial_chord` reads one history and finds
   the one face button that went down, with the direction and the
   triggers as they stand.
3. **It reads the buttons and the sticks itself, at one instant.**
   Joining 502's button history and 503's stick history at one station
   would pair two streams. Values may leave a port in a different order
   than they arrived (`034-ports.c`), so one frame's buttons could meet
   another frame's stick. `radial_read` reads both surfaces in one
   frame, and one history goes round one loop. The stick math (the
   resting circle and the eight sectors) moved from `095-input.c`'s
   private helpers to `096-input.c` (`input_stick_inside`,
   `input_stick_direction`), because the catalogue keeps each box
   file's private helpers to itself. 503's boxes call the same two.
4. **The direction source is configurable, and fixed per map**: a mask
   of D-pad (1), left stick (2) and right stick (4). The map uses the
   D-pad and the left stick (3): both sit under the left thumb, and
   docs/004 says "the user picks whichever feels better in the moment".
   When both point, the D-pad wins. The right stick is under the same
   thumb as A, B, X and Y, so it is off by default. A mask with none of
   the three refuses the station (detail 1).
5. **The D-pad's eight ways**: one bit is straight on, two neighbours
   are the diagonal between them. Two opposites, or three or four bits,
   point nowhere.
6. **The modes**: the triggers held, as four bits (L1 1, R1 2, L2 4,
   R2 8), index a sixteen-entry `select` list, which names a mode 0 to
   3 or -1 for none. By default nothing held is mode 0, L1 mode 1, R1
   mode 2, L2 mode 3, and every other combination is none. L1 with R1
   is the editor's own mode toggle (docs/008). A `select` naming any
   other mode refuses the chord station, with detail 2 + the
   combination.
7. **The table**: four lines of up to thirty-two characters. Within a
   line the order is n, ne, e, se, s, sw, w, nw, and within a direction
   A, B, X, Y. A line shorter than thirty-two leaves the places after it
   empty, and an empty place types nothing. The default:
   - mode 0: lower case, space and `. , ? ! '`;
   - mode 1: upper case, a new line and `- : ; " /`;
   - mode 2: digits and the operators and brackets;
   - mode 3: `` ` ``, `\` and a tab, with the rest free.
   The layout is a first guess, meant to be remapped.
8. **The default table lives in the map**, as the `chord` station's fixed
   value. The issue named a separate `/system-maps/radial-menu-table-default.json`.
   Maps are text now, the map itself is the system map on the card, and
   a table beside it would need `read-path` (406, still in PR #35) for
   nothing.
9. **A user's own table replaces it through a call,
   `radial_menu_set_table`** (`src/system/133-radial-menu.h`). The call
   turns the station's dial in place, so the next frame types from the
   new table. A map door cannot do this: a port with a fixed value
   cannot also be an argument (the loader refuses the second source).
   Reading the user's table from `/settings/` is the editor's part
   (801).
10. **One character an event.** `struct radial_event` holds the character
    (one byte, as a number), the direction, the button and the mode. It
    is ordered by the character, so a comparator against all zeros lets
    only typed characters out of the program's result door. It is
    24 bytes, inside a comparator's 64.
11. **Not wired into input-poll.map.** As 505 decided for chords, which
    chords exist is the apps' business. The editor (801) and the
    messenger (805) place `radial-menu-chord.map` and wire input-poll's
    frame into its door 0. What the menu shows on screen while a
    direction is held is the editor's drawing (801); the table and the
    held direction are all it needs.
12. **Handedness does not touch it**, as the issue says. 507's applier
    stands between the raw events and the apps, not in front of this.

## What happened

Built on the twin as decided above.

- `src/boxes/131-radial-menu.c` — `radial_read`, `radial_at_rest`,
  `radial_track`, `radial_chord` (the comparator's box) and
  `say_radial` for the developer line.
- `src/maps/radial-menu-chord.map` — the program: the frame in by door 0,
  characters out by door 0, the default table.
- `src/system/133-radial-menu.c/.h` — `radial_menu_set_table`.
- `src/system/096-input.c/.h` — the stick math, shared (decision 3).
- `twin/tests/132-test-radial-menu.c` (43 checks):
  - the D-pad's eight ways and the pairs that point nowhere; the
    sources and their order; the resting circle;
  - every one of the 128 places against the chord that reaches it;
  - the chords that type nothing;
  - the program typing "hello, world" and "Room 101: OK";
  - a held direction typing once a press; the stick standing in for
    the D-pad;
  - a user's table taking effect on the next frame, and refused for the
    wrong size or a mode that does not exist;
  - the program placed inside another map, its characters said there,
    and a table given to the placed one.

Waiting for the device: the reads themselves (101), as for 502 and 503.

## Related documents

- `docs/004-input-model.md` — the radial menu chord section.
- `notes/vision/000-vision.md` — the radial menu's role.

## Blocked by

502, 503 (direction source), 505.

## Blocks

508, phase 8 (the editor consumes this).
