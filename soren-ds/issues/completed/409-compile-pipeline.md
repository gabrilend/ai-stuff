# 409 — Compiling a box on the device

## Current behavior

**Every box in the system was decided before the device booted.**

The generator reads whatever sits in the box source directory, emits a
call site and a catalogue row for each, and all of it is compiled into
the image. So placing a station by the text `boxes/text.c:add` reaches a
compiled C function — which is the whole trick that lets a text file
describe a program — and the set of addresses that trick works for is
frozen at build time.

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

**Its address is the file its source was saved to**, and that is why this
step matters beyond itself. A station line names a file and a function
(305), so a box compiled here needs a file it can honestly claim — and it
has one, because the source arrived by being written somewhere: the card
through the read path (406), or the editor's save (phase 6). Nothing has to
be invented, and nothing has to be special-cased.

What that buys is the thing on-device authoring is for: **a program written
at the touchscreen can be written back out and built again.** A box whose
address named a scratch location belonging to the running system would be a
box nothing could record, so a program containing one could be described
but never rebuilt — it would be a description plus the running system that
already held the code. The parent project spent three attempts on that
problem from the other end before changing what saving a program means; see
`docs/012-soramech-runtime.md`, *How a program gets written back out*.

**The catalogue becomes a growable table.** It is looked up by address
when a station is placed and by row afterwards, so it takes the same paging
shape as everything else here that grows: add a block, never move what
is already there, and a reader resolving a row is never disturbed. That
is the fourth use of this pattern in the system — after the station
table, a port's cells, and the allocator's stripes — and by now it
should be one shared piece rather than a fourth hand-rolled one.

**Where the compiler comes from: assume it is there.** The device calls
a C compiler and does not negotiate about it. Embedding a small one is
the likely answer given there is no package manager on a handheld, and
the choice belongs to implementation rather than to this issue. *(Chosen
below, revisably: TinyCC, behind `platform_compile`.)* What
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

### Proposed answers (UNVERIFIED)

1. *Which compiler?* **TinyCC (libtcc), behind a pluggable compile
   step. A revisable decision: Ritz can overturn it, and overturning it
   touches one function.** TinyCC is small (a few hundred kilobytes of
   code), compiles straight into memory with no files and no linker run
   (`tcc_new`, `tcc_set_output_type(TCC_OUTPUT_MEMORY)`,
   `tcc_compile_string`, `tcc_relocate`, `tcc_get_symbol` map one-to-one
   onto what `platform_compile` must do), and has an arm64 back end. What
   was given up: a C subset written for box semantics would be tighter
   and could refuse what a box may not do, but it is a month of writing
   and a second C dialect to keep true; TinyCC's code is slower than
   gcc's, which matters little for a box someone typed at the
   touchscreen and can be revisited by compiling hot boxes into the next
   image. The step stays pluggable because it already is: the pipeline
   hands generated C to `platform_compile` and takes back an entry
   function, so TinyCC (or anything else) slots in behind that one call
   in `src/device/042-platform-device.c` without touching the engine. The
   twin answers it with the laptop's gcc and `dlopen`. **TinyCC is not
   vendored yet**: copying it into the project waits for device bring-up
   (201, 202, 401), when it can be built for the device and tried there.
   Until then the device answers "this device's C compiler (TinyCC) is not
   built in yet", in those words, and the pipeline passes them back as
   the refusal.
2. *Does the on-device generator share the build's describe mode?* It
   shares the generator itself — the same `gen_read` over the same
   source, and its problems come back verbatim as the refusal, every one,
   each naming the card path and line. What the touchscreen shows of them
   is phase 6's to decide; `gen_describe` is callable from here when it
   does.
3. *A box compiled and never placed?* It keeps its row, its code and its
   source until 410 reclaims it. Each unit is recorded (path, boxes,
   when, the kept source, the platform's handle) so 410 has something to
   retire.
4. *(new)* **Compiling a file again makes a newer unit beside the old**,
   rather than being refused because the address is taken. Somebody
   saving a box fifteen times produces fifteen units with the same
   addresses (410's own example), and 411 needs the old and the new to
   coexist so the arrows can move and move back. Looking an address up
   answers the newest; a station already placed on an older one keeps
   running it, because its ports were sized to it. An address the image's
   own rows hold cannot be compiled over: the image's files are not the
   card's.
5. *(new)* **The late source is written into the generated unit**, under
   `#line` marks naming the card path, instead of being `#include`d: on
   the device there is no file a compiler could include, and the marks
   make the compiler's own words name the file and line a person saved.
6. *(new)* **The catalogue's growing tables share one piece**,
   `src/engine/086-shelves.c`: rows, types, and the compile units. The
   station table keeps its own copy of the shape inside the engine's
   record, where index-to-shelf is a shift on the hottest path; moving it
   onto the shared piece is a refactor of phase 2's core with no
   behaviour to gain, so it was left.
7. *(new)* **A unit's value types are copied into the catalogue**, name
   and fields, so a map can write a fixed value of a type only a late box
   defines, and so the copy outlives the unit's code when 410 frees it.
   A type name the catalogue already knows keeps its first row — types
   are compared by width, never by layout (303) — and the copy carries no
   ordering, which nothing reads from a type row.
8. *(new)* **The source is kept in the engine's own memory**, which is
   RAM and empties at a reboot — the lifetime the issue gives the
   RAM-backed tier — because the device's tmp/ tier is not a filesystem
   yet. It is found again from the file's path or any of its boxes'
   addresses (`compile_source`).
9. *(new)* **The engine is not held while the compiler runs.** The
   generator runs holding it (its memory comes from the per-owner
   allocator), the compiler runs with nothing held, and the rows are
   added holding it again, all at once.
10. *(new, found while building)* Two faults, fixed:
    - **A program placing a late box was written back out wrongly**: the
      map writer climbed out of the map's directory with `..` towards a
      card path, writing `../..//boxes/text.c:join`, which reads back as
      a project path. An address on the card is now written as it is.
    - **`number_text` (063-text.c) returned stack bytes past the text's
      end**, so the same number made two different values. It now
      zeroes the value first.
    And on the twin, a unit's names are hidden but its entry: without
    that, a late box called `add` called the image's `add` instead of
    its own.

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
