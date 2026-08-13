# 409 — Compiling a box on the device

## Current behavior

**Every box in the system was decided before the device booted.**

The generator reads whatever sits in the box source directory, emits a
call site and a catalogue row for each, and all of it is compiled into
the image. So placing a station by the text `"add"` reaches a compiled C
function — which is the whole trick that lets a text file describe a
program — and the set of names that trick works for is frozen at build
time.

Phase 3 made that limit visible rather than creating it. A program can
grow stations, ports and arrows while it runs; every one of those
stations must place a box the device was built with. You can rearrange
the furniture but not bring in new furniture.

## Intended behavior

**A box's C source can be handed to a running device, and a station can
place it.**

Each step already exists somewhere:

```
   1  the source arrives            through read-path (406), or
                │                   the editor's save (phase 6)
                ▼
   2  the generator runs over it    the same generator — which is why
                │                   304 made it a C program
                ▼
   3  a compiler produces code      into a page from 203, marked
                │                   executable
                ▼
   4  a catalogue row is added      name, call site, each input's
                │                   width, return width, task size
                ▼
   5  a station places it           and the arrows are drawn (411)
```

**There is no version of this that skips the compiler**, and the reason
is worth stating because it looks skippable. A function signature gives
you *names* — the box's name, its parameter type names, its return type
name. What it cannot give you is **widths**: how many bytes a cell
holds, how far into a struct a field sits, how large a task must be.
Those are what the engine actually runs on, and the standing rule is
that the compiler computes every one of them and the generator never
guesses. The signature supplies the paperwork; a compiler supplies the
numbers.

**A box arriving late asks nothing the type system cannot answer.** It
reports the width of each input and of its output, by the same `sizeof`
the compiler computes for every box compiled into the image. So it goes
through the identical wire check, and it **introduces no new kind of
error** — two same-width structs with different layouts already wire at
build time (303), and a box compiled later makes that likelier without
making it different.

**The catalogue becomes a growable table.** It is looked up by name when
a station is placed and by row afterwards, so it takes the same paging
shape as everything else here that grows: add a block, never move what
is already there, and a reader resolving a row is never disturbed. That
is the fourth use of this pattern in the system — after the station
table, a port's cells, and the allocator's stripes — and by now it
should be one shared piece rather than a fourth hand-rolled one.

**Where the compiler comes from: assume it is there.** The device calls
a C compiler and does not negotiate about it. Embedding a small one is
the likely answer given there is no package manager on a handheld, and
the choice belongs to implementation rather than to this issue. What
this issue commits to is the behaviour: source in, a placeable box out,
or a refusal naming the compiler's own output rather than a summary of
it.

**A failed generation leaves nothing loadable**, the same guarantee the
build already keeps: write to a scratch name, move into place only on
success. A device that half-loads a box is a device with a catalogue row
pointing at code that does not exist.

**The source is written down at the moment the box is created**, not
when something asks for it later. A program written back out as text has
to be reloadable, and a box that exists only as code in a page cannot be
described. Saving it at creation is the same decision as opening a crash
report's destination during startup: the artifact exists before anybody
needs it, because the moment somebody needs it is the worst moment to
discover it is missing.

## Suggested implementation steps

1. Make the catalogue growable and paged, sharing the mechanism the
   station table already uses.
2. Compile-and-load as one deliberate call: source in, a call site out,
   failures naming the compiler's own words.
3. Adding a catalogue row — name, call site, per-input widths, return
   width, task size, and an ordering if the type has one. Nothing about
   the new box's types is checked against anything, because 303 checks
   widths when an arrow is drawn and there is nothing earlier worth
   asking.
4. Saving the source to the RAM-backed tier as the box comes into
   existence, named so a reload can find it from the box's name alone.
5. A test that a box written after boot is placed, wired, and delivers
   values byte-identically to one compiled into the image.
6. A test that a box whose input is a different **width** from what
   feeds it is refused, naming both types and both widths — the same
   refusal, arriving by the same path.
7. A test that a box whose struct disagrees in *layout* with one already
   loaded, at the same width, **is accepted and delivers scrambled
   fields.** Written deliberately, because it is the accepted cost of
   comparing widths, and a test that pins it is how somebody later finds
   a decision rather than an oversight.

## Open questions

- *Which compiler?* A small embeddable one is a month of integration; a
  minimal C-subset compiler written for box semantics is a month of
  writing. The second is tighter and the first is likelier correct. The
  decision wants writing down where it is made, with what was given up.
- *Does the on-device generator share the build's describe mode?* It
  should — a second way of reporting what the parser saw is a second
  thing that can disagree — but the build prints to a terminal and the
  device has a touchscreen.
- *What happens to a box compiled and never placed?* It holds a
  catalogue row and a page of code forever unless something unloads it,
  which 410 handles. Somebody editing all afternoon produces a lot of
  these.

## Blocked by

203 (pages to compile into), 302 and 304 (the generator, and its being
callable at all), 303 (width comparison, without which this corrupts
silently), 406 (how the source arrives).

## Blocks

410, 411, 412.

## Related

- [302 — The generator](302-the-generator.md), run here at runtime
- [303 — Types compared by width](303-types-compared-by-width.md), a
  hard prerequisite
- [410 — Code that outlives the boxes that used it](410-code-that-outlives-its-boxes.md)
- [411 — Replacing a box in a running program](411-replacing-a-box-in-a-running-program.md)
