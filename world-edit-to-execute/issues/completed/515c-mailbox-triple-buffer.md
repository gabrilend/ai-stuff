# Issue 515c: Mailbox Triple Buffer

**Phase:** 5 - Rendering
**Type:** Implementation
**Priority:** Medium
**Parent:** 515 (the render graph on the ceramic engine)
**Dependencies:** 515b
**Blocks:** 515d, 515f

---

## Current Behavior

Built (2026-09-25).

- **The mailbox** (`src/render/ceramic/mailbox/`): `mailbox.h`, its tests
  and `run-mailbox-tests.sh`. Every test passes:
  - the plain order;
  - one writer and four writers racing one reader, 300,000 states each:
    nothing torn, nothing out of order;
  - the broken mailbox is caught (about half its takes torn);
  - ThreadSanitizer finds nothing.
- **The host** (`src/render/ceramic/host/`) draws through it. The unit
  record is widened to 36 bytes. `--check` takes 600 states through the
  mailbox while the feeder races and every unit matches.
- **The numbers** (this machine):
  - uncapped (picture mode): 725 frames a second, against 472 when the
    engine and the drawing took turns; the engine's 0.18 ms now runs beside
    the drawing instead of before it;
  - capped at 60 in a window: the state is **17.8 ms old** when drawn,
    against about 0.2 ms when the draw thread waited for the engine.
    Pacing by take means state N+1 is worked out right after frame N is
    taken, then waits in the mailbox for frame N+1: a whole frame.

**Pacing, decided with the owner (2026-09-25): pacing by take stays.** The
three ways weighed:
1. **Pacing by take (chosen).** Extrapolation (515d) draws "now" from each
   record's velocity, so the frame of age is hidden rather than removed.
   Closest to the real game, where the writer is the network delivering the
   server's states at the server's times, and the draw can't choose them.
2. **Just in time** (not taken): the feeder waits until shortly before the
   next draw is due, then works out the state for that moment. Age near
   zero, but a late guess means a repeated frame, and the real game's states
   can't be worked out on demand.
3. **Run free** (not taken): age about the engine's time, but every core
   but one busy producing states that are mostly thrown away.

## Intended Behavior

The visual state passes from the engine to the draw thread through a
**mailbox**: a small set of whole-state buffers and one shared word saying
which buffer holds the newest complete state.

**The mailbox** (`src/render/ceramic/mailbox/mailbox.h`, generic over the
buffer's size):
- **Buffers:** one per writer, one for the reader, and one "latest complete"
  in the middle; with one writer, that's the triple buffer. Each writer and
  the reader hold their own buffer; only the middle one is shared.
- **The shared word** (32-bit, atomic) holds the middle buffer's number
  plus a "fresh" bit: set when a writer puts a buffer there, cleared when
  the reader takes it.
- **Publishing** (a writer finished its buffer): one atomic exchange puts
  its buffer in the middle, marked fresh, and hands it back whatever was
  there, which it writes next. A fresh buffer nobody drew is simply written
  over: a newer state replaces an older waiting one, it never queues.
- **Taking** (the reader, starting a draw): if the middle is fresh, one
  atomic exchange swaps the reader's buffer for it; otherwise the reader
  keeps drawing what it has. Only the reader clears the fresh bit, so the
  glance before the exchange cannot be fooled.
- **Neither side waits** on the other, and a buffer is only ever touched by
  the one thread holding it, so a half-written state is never drawn.
- **Ordering:** both exchanges are acquire-release: the writer's stores are
  visible to whoever takes its buffer, and the reader's reads finish before a
  writer is handed that buffer back.
- **One reader.** Two readers would take each other's fresh states. The
  owner's issue text asked for "many writer and reader threads"; many
  writers work (each has its own buffer), many readers don't, and the draw
  thread is the only one.

**The state in a buffer** (`unit_state` in the host): the frame number, the
time the state was true (seconds, `float`), the moment it was published,
and the eight lanes' units. Each unit record: position (x, y, z), velocity
(x, y, z), facing (radians), animation phase (radians), and colour
(0xRRGGBBAA), all 32-bit: 36 bytes. The time is per state, since the engine
works out every unit for one instant. Velocity, facing and animation are
what extrapolation (515d) will draw "now" from.

**The host** (`src/render/ceramic/host/units-host.c`):
- **The feeder,** a thread of its own, drives the engine. For each state, it
  re-arms every lane's landing to go straight into the buffer it is writing
  (so the engine's landing copy is the only copy), hands in the tick and the
  lanes as one batch, waits until all eight have landed, stamps the frame
  number and time, and publishes.
- **Pacing:** after publishing, the feeder starts the next state as soon as
  the draw thread has taken the last one. It computes state N+1 while frame
  N is drawn: one state per drawn frame, and no core spinning on states
  nobody will see.
- **The draw thread** takes the newest state as late as it can (after the
  camera moves, just before drawing) and never waits for the feeder. The
  window opens on a complete first state.
- **The numbers on screen:** the draw thread's time per frame, the state's
  age when drawn, and how many frames drew a state again (the feeder was
  late). No state goes undrawn: with pacing by take, the feeder never
  publishes over a state the draw hasn't taken.

**Tests** (`src/render/ceramic/mailbox/test-mailbox.c`):
- the plain order: nothing new before a publish; a publish is taken once;
  of two publishes, the second is the one taken;
- one writer and one reader racing for millions of states, a state being
  thousands of words all stamped with the state's number: every taken
  buffer is whole, and the numbers only go up;
- four writers and one reader, the same, with each writer's numbers only
  going up;
- **the tests have teeth:** the same race against a deliberately broken
  mailbox (publishing without taking a new buffer, so the writer goes on
  writing the one just handed over) must fail;
- run again under ThreadSanitizer;
- in the host, `--check` takes states through the mailbox while the feeder
  races, and compares every unit of every taken state with the direct
  arithmetic at that state's time.

## Suggested Implementation Steps

1. `mailbox.h`: create, a writer's buffer, publish, take, destroy.
2. `test-mailbox.c` and `run-mailbox-tests.sh` (normal, broken, sanitizer).
3. Widen the unit record (`units-boxes.c`, `units-types.lua`).
4. The host: the feeder thread, the pacing, the draw thread's take, the
   numbers; `--check` and `--shot` through the mailbox.
5. Record in 515 what it taught (the frame of age, and why extrapolation
   answers it).

## Acceptance Criteria

- [x] The mailbox and its tests, passing, including the broken mailbox failing
      and ThreadSanitizer finding nothing
- [x] The host draws through the mailbox; `--check` passes through it
- [x] `.info.md` beside each new source file

## Related Documents

- `issues/515-render-graph-on-the-ceramic-engine.md` (the design, point 2)
- `issues/completed/515b-ceramic-host-loop.md`
