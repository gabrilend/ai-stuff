# Phase 3 progress — Soramech runtime

Phase 3 builds the runtime that turns the threading core from
phase 2 into something a soramech map can run on. By the end of
the phase, the device can take a small in-memory map description,
allocate the slot store it needs, hook every wire into the right
slot, splice any encapsulated sub-maps into the parent graph,
detect cycles, run the map until quiescence with values flowing
along wires under the routing-kind dispatcher's direction, and
stream a JSONL-shaped transcript through the USB CDC-ACM stream
that lets the developer watch the run live.

This phase ships before the filesystem (phase 4), so the first
maps it runs are statically embedded in the kernel image rather
than read from the SD card. The compile pipeline and hot-swap
mechanism that the soramech-runtime doc describes both wait on
phase 4 because the artifact tree needs a place to live.

## The story of the phase

1. `301-in-memory-map-representation.md` — the data structures
   that hold a loaded map.
2. `302-box-source-format.md` — the JSON shape map files carry,
   pinned now so phase 4 can read them off disk later.
3. `303-map-loader.md` — turns JSON into a `map_t` ready to run.
4. `304-wire-connector.md` — walks each producer's connections
   list and hooks outputs to consumer slots.
5. `305-encapsulation-splicer.md` — flattens `kind: "map"` boxes
   into the parent graph at load time, prefix-renaming the
   sub-map's box ids.
6. `306-cycle-detector.md` — DFS on the flattened graph, refuses
   to start a map with a cycle.
7. `307-routing-dispatcher.md` — the seven routing-kind patterns
   (plain, comparator, iterator, randomizer, weighted,
   distributor, nonlinearity), each implemented as a small
   dispatch function the worker calls when pushing outputs.
8. `308-map-execution-and-quiescence.md` — submits entry tasks
   to kick the map; watches for the run-empty condition that
   means the map has quiesced.
9. `309-launch-utility-boxes.md` — debug-write, timer, panic,
   pseudo-random. Adds to the descriptor table that phase 2's
   208 established.
10. `310-ram-transcript-ring.md` — fixed-size in-RAM event ring
    the panic handler dumps through CDC-ACM, replacing the
    JSONL-on-disk transcript from soramech proper.
11. `311-phase-3-demo.md` — wires a tiny in-kernel "hello world"
    map, runs it through the runtime, watches the output stream
    through the serial port. The first thing the device runs
    that is more than direct C kernel code.

## Completed issues

None yet.

## Open issues

All of 301 through 311.

## Phase demo

`issues/completed/demos/phase-3/run.sh` will exist once the
phase closes. It builds the kernel image with the demo map
statically linked in, flashes via chip ROM recovery, opens the
CDC-ACM stream, watches the transcript events scroll past, and
asserts the demo map's final output value matches the expected
result.
