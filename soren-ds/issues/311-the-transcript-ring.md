# 311 — The transcript ring

## Current behavior

**The device remembers what went wrong and not what was happening.**

Phase 2's error records are one fixed slot per station, written in
place and counted rather than appended, so the same failure a million
times is one slot reading a million. That is the right shape for an
ordinary build: bounded by construction, no allocation, no growth, and
it answers *what failed and how often* exactly.

What it cannot answer is *what was going on just before the first
one* — which is the question somebody actually has when a device that
ran for six hours stops.

## Intended behavior

**A fixed-size ring of recent events, in RAM, in debug builds only.**

| build | error records (214) | transcript ring |
|---|---|---|
| ordinary | yes — counted in place | no |
| debug | yes, with timestamps | yes |

This follows the line 214 already drew. The snapshot before every box
call is a debug-build cost because it is paid per run to catch
something rare; so is this. Somebody authoring on the device runs the
debug build, which is precisely when a crash is expected and when
losing the history is expensive.

**The ring never grows and never allocates.** A flat array of
fixed-size records; a counter that advances; the oldest entry is
overwritten when it wraps. Long text is truncated in place rather than
pointed at, because a pointer into anything is a pointer that can
outlive what it points at.

| recorded | fields |
|---|---|
| a task was queued | which station, which task |
| a task started | which task, which core |
| a task finished | which task, how long, how many bytes out |
| a value was delivered | from which station, to which station and port |
| a station was placed or wired | which, and what to |
| a station removed itself | which, and why (214's kinds) |

```
   ┌────┬────┬────┬────┬────┬────┬────┬────┐
   │ 96 │ 97 │ 98 │ 91 │ 92 │ 93 │ 94 │ 95 │  overwritten in place
   └────┴────┴────┴────┴────┴────┴────┴────┘
                  ▲
              oldest still here

   a crash dumps from the oldest forward. nothing is lost
   except what was too old to matter.
```

**Two readers.**

*The live stream* — while a laptop is attached to the serial line, a
low-priority station drains the ring and writes each event out as text.
When nothing is attached it is a no-op, so the cost of the feature on a
device sitting on its own is a counter comparison.

*The crash dump* — the panic path walks the ring from the oldest entry
forward and writes every one out before parking the core. It runs
whether or not the live stream was running, because the crash is
usually the first time anybody wanted the history.

**It replaces the phase 1 SD-card log.** Phase 1 writes a diagnostic
log into a reserved region of the microSD card, because bring-up tests
deliberately run with nothing attached over USB and serial-only output
goes nowhere. This is the same "last N events before a stop", kept in
RAM, with no card wear and no region of removable media spent on kernel
logs. When this lands, that region and its source file both go — and
that removal is part of this issue rather than a loose end after it.

## Suggested implementation steps

1. The record — fixed size, no pointers, text truncated in place.
2. The ring and its counter, with the write being one advance and one
   store. It is on the hot path in a debug build, so it may not take a
   lock.
3. Emission points at the events above, each behind the debug flag.
4. The live-stream drain, as an ordinary station, so it is scheduled
   like everything else and cannot starve the work it is watching.
5. The crash-dump walk, hooked into the existing panic path.
6. Remove the phase 1 SD-card log and its reserved region, and update
   that issue to say where its job went.
7. A test that a debug build under load never loses an event that
   should still be resident, and that an ordinary build carries none of
   this.

## Open questions

- *How many entries?* Enough that the live stream keeps up under normal
  load, which is a measurement rather than a guess, and 215's endurance
  run is where to take it. A few thousand is the shape of the answer.
- *Is a low-priority station really the right home for the drain?* It
  is scheduled fairly with everything else, which is the point — but
  under heavy load it competes with the work it exists to observe, and
  the ring wraps. Draining from the idle path instead would only run
  when nothing else needs a core, which is more correct and means a
  busy device streams nothing until it goes quiet.
- *Do the timestamps come from the same clock everything else uses?*
  They should, or two events cannot be ordered against a measurement
  taken elsewhere. Phase 1's clock work has the answer and it wants
  writing down here.

## Blocked by

105, 108, 110, 214.

## Blocks

312.

## Related

- [214 — When a box removes itself](214-when-a-box-removes-itself.md),
  the ordinary build's whole memory
- [110g — SD-card debug log](completed/110g-sd-card-debug-log.md),
  which this retires
- [015 — LED diagnostic codes](../docs/015-led-diagnostic-codes.md)
