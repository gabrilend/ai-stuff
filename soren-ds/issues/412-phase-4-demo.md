# 412 — Phase 4 demo

## Current behavior

Issues 401 through 411 produce a working filesystem, the persistence
convention is wired, and a box written on the device can be compiled,
placed, and wired into a program that is already running. Phase 4 needs
a demo that exercises every piece end to end.

## Intended behavior

The demo has three movements, scripted in
`issues/completed/demos/phase-4/run.sh`:

### 1. File round-trip across reboot

The kernel writes a known byte sequence to
`/test/round-trip.bin` through `write-path`. The kernel then
issues a software reboot. After the reboot, the kernel reads
the file back through `read-path` and asserts the bytes match.
This proves the FAT layer correctly persists data to the
physical SD card and that the temp-and-rename pattern in
`write-path` survives a fresh boot.

### 2. A box written on the device, put to work

The image carries a small program with one box that returns a constant,
running and saying that constant once a second.

| the demo does | and asserts |
|---|---|
| writes new source to the card, returning a different constant | — |
| runs the generator and the compiler over it | a catalogue row appears for the new box |
| places a station on it, moves the arrows, unwires the old | the said number changes at the first run afterwards, and never mid-value |
| writes the running program back out | the file shows the new station wired and the old one with no source |

This proves the generator on the device, the compiler, the growable
catalogue, and the four construction operations working as one system.

### 3. Old code goes away, and only when it can

The demo compiles a box **and never places it**, then compiles a second
one and places that. It asserts:

- the unplaced box's page is filed rather than freed immediately
- a sweep frees it while the device stays saturated with work
- the *placed* box's page is never freed, and the sweep says why rather
  than skipping it silently
- a core parked with nothing to do does not stall the sweep — which is
  the property the whole counter scheme exists for, and the one a
  naive check-in scheme would deadlock on

The script asserts each movement's expected state and reports pass or
fail.

## Suggested implementation steps

1. The round-trip portion of the script — write, reboot,
   read, assert.
2. The swap-demo embedded map plus the box source on the SD
   card.
3. The reclamation harness — compile without placing, compile and
   place, then sweep under load.
4. The shell script wrapping build / flash / orchestration.

## Related documents

- `docs/002-roadmap.md` — phase 4 demo description.
- `docs/011-filesystem.md`.
- `docs/012-soramech-runtime.md`.

## Blocked by

All of 401 through 411.

## Closes

Phase 4.
