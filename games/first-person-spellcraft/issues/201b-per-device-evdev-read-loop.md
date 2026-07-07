# 201b — Per-device evdev read loop

> **Phase:** 2 — Dual-Mouse Aiming & Input
> **Difficulty:** hard (binary parsing + real-time cadence)
> **Depends on / blockers:** [201a](201a-discover-and-open-two-distinct-mice.md)
> (needs the open, grabbed device handles); Phase 1 loop (owns the per-tick input
> hook).
> **Blocks:** 202 (per-hand state) and everything downstream.
> **Parent issue:** 201 (raw multi-device mouse reading), split into 201a
> discovery/opening and 201b the read loop.

## Current Behavior

None of this exists yet — greenfield. We have (from 201a) two open, grabbed
device handles, but nothing reads bytes from them or turns those bytes into
motion the game understands.

## Intended Behavior

Once per game tick, called from the Phase 1 loop's input hook, the game **drains
every event queued on each device** and reduces it to a compact per-tick summary:
how far that mouse moved (x, y, wheel) and which buttons changed. Reading is
**non-blocking** — it takes whatever is waiting and returns immediately, never
stalling the frame waiting on a still mouse.

The read loop understands the three event kinds it needs:

- **Relative motion** (`EV_REL`): accumulate X, Y, and wheel deltas.
- **Buttons** (`EV_KEY` with mouse-button codes): record press and release
  *edges* for this tick (so a consumer can tell "clicked this frame" from "held").
- **Frame terminator** (`EV_SYN` / `SYN_REPORT`): the kernel batches the deltas
  of one physical movement and closes the batch with a report event. Deltas are
  applied as a coherent frame at the report boundary, not smeared across ticks.

The output is two **per-device tick accumulators** (left, right), each zeroed at
the start of the drain and filled as records are consumed. This is the last stage
that speaks "device"; everything above it speaks "hand."

## Suggested Implementation Steps

1. **Describe the record via LuaJIT FFI.** Declare the `struct input_event`
   layout so a chunk of bytes read from the fd can be cast in place (no copy). The
   record is a timestamp, a 16-bit `type`, a 16-bit `code`, and a 32-bit `value`;
   the fixed record size is what the read loop reads in whole multiples of.
2. **Read in bulk, cast in place.** Each tick, `read` a buffer's worth of bytes
   from each device fd (non-blocking; treat "would block / no data" as simply
   "nothing this tick," not an error). Iterate the buffer in record-sized strides,
   casting each stride to the event view.
3. **Dispatch by event type via a table, not an if/else ladder.** A small dispatch
   table keyed by event `type` (`EV_REL`, `EV_KEY`, `EV_SYN`) routes each record
   to its handler. Per project convention, prefer the dispatch table — indexing a
   handler is cheaper and clearer than a switch.
4. **Accumulate.** `EV_REL` handlers add into the accumulator's x / y / wheel by
   `code`. `EV_KEY` handlers set the pressed/released edge for the button `code`.
   `EV_SYN`/`SYN_REPORT` marks a completed movement frame.
5. **Zero-and-fill discipline.** Zero each accumulator at drain start so a tick
   with no motion reports exactly zero. (No nil — an idle mouse reports a real
   zero delta, never an absent one. Nil checks here would be inventing a state the
   hardware does not have.)
6. **Recorded-trace test path.** Support reading the byte stream from a **captured
   trace file** instead of a live device, so the loop is testable with no second
   mouse plugged in. A capture utility (dump raw `input_event` bytes from a device
   to a file) doubles as a fixture generator. This is how stage [1]-[2] is tested
   per the datapath doc.

## Structures & Functions By Role

- The **event record view** (FFI struct declaration + cast helper).
- A **per-device tick accumulator**: x, y, wheel sums; per-button pressed/released
  edge flags; a "saw a report this tick" marker.
- A **drain one device** function (bulk read → iterate records → dispatch → fill
  accumulator), and a **drain all devices** function called by the loop's input
  hook.
- The **event-type dispatch table** and its per-type handlers.
- A **trace source** variant of the reader (file-backed) sharing the same
  dispatch, for tests.

## Data-Format Facts To Record As Comments

- `struct input_event` on 64-bit Linux: a `timeval` (two machine longs, 16 bytes),
  then `type` (u16), `code` (u16), `value` (s32) — 24 bytes total. Read only in
  whole-record multiples.
- Codes worth naming: motion `REL_X`, `REL_Y`, `REL_WHEEL`; buttons `BTN_LEFT`,
  `BTN_RIGHT`, `BTN_MIDDLE`; frame end `EV_SYN` with `SYN_REPORT` (value ignored).
- Non-blocking reads return a "would block" errno when the queue is empty; that is
  the normal idle case, not a fault.

## Related Documents / Tools

- Datapath: [datapath-dual-mouse-input.md](../docs/datapath-dual-mouse-input.md)
  — stages [1] raw stream and [2] per-device drain.
- Upstream: [201a](201a-discover-and-open-two-distinct-mice.md) provides the
  handles.
- Downstream: [202 — per-hand state and hand-role assignment](202-per-hand-state-and-hand-role-assignment.md)
  consumes the accumulators.
