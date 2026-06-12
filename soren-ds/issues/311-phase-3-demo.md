# 311 — Phase 3 demo

## Current behavior

Issues 301 through 310 produce a working soramech runtime on top
of phase 2's threading core. The threading core's torture test
from 211 proved the substrate. Phase 3 needs its own demo that
proves the runtime above the substrate also works end to end —
a real (small) soramech map loaded, run, and observed.

## Intended behavior

A tiny "hello, world" map ships statically embedded in the kernel
image. The map has three boxes:

```
greeting-source ──→ formatter ──→ debug-write
```

- `greeting-source` is a read box whose value is the literal
  string `"world"`.
- `formatter` is a call box. Its C function takes one string
  input, returns the string `"Hello, world!"`. (Phase 4's compile
  pipeline isn't ready yet, so the formatter is statically
  linked alongside the launch utility boxes.)
- `debug-write` is the launch utility box from 309. Its input is
  the formatter's output; it pushes the bytes through CDC-ACM.

The demo script at `issues/completed/demos/phase-3/run.sh`
builds the kernel image, flashes it through chip ROM recovery,
opens the CDC-ACM serial port, and watches for two things:

1. The transcript ring's live stream emits a series of events
   ending in a `task_end` for the debug-write box and a
   `run_end` for the demo map.
2. Among the bytes the kernel wrote to the CDC-ACM stream is
   the literal `"Hello, world!"` text.

Both conditions hold: pass. Either misses: fail, with the
captured stream printed verbatim for diagnosis.

The script follows the project convention — hard-coded `${DIR}`
at top, override as first argument, paths relative to `${DIR}`.

## What the demo proves

- The map loader can turn statically-embedded JSON source into a
  runnable map_t.
- The wire connector hooked the formatter's input to the
  greeting-source's output, and the debug-write's input to the
  formatter's output.
- The gathering function fired the formatter once
  greeting-source pushed its value, and fired debug-write once
  the formatter's value landed.
- The routing dispatcher correctly handled `plain` routing on
  all three boxes (the demo doesn't exercise the other six
  routing kinds — those get a follow-up integration test
  scheduled before phase 5).
- The transcript ring captured the lifecycle and the live
  stream emitted it through CDC-ACM.

## Suggested implementation steps

1. Statically embed `boxes/*.json` + `meta.json` for the demo
   map as C string constants the loader reads in place of a
   real path.
2. Write the `formatter` box function and add its descriptor.
3. `run_phase_3_demo()` — load the embedded map, call
   `map_run`, wait for quiescence.
4. The shell script wrapping build / flash / stream / verify.
5. A second test map that exercises each of the seven routing
   kinds in turn, run as a follow-up after the "hello, world"
   pass. Each kind's expected output is checked against a
   closed-form value.

## Related documents

- `docs/002-roadmap.md` — phase 3 demo description.
- `docs/012-soramech-runtime.md`.

## Blocked by

All of 301 through 310.

## Closes

Phase 3.
