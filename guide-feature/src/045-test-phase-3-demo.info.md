# 045-test-phase-3-demo — info

Tests for the phase 3 demo (`issues/completed/demos/phase-3-demo` and
`phase-3-demo.lua`). It runs against a copy of the project with its own
git checkout and fast settings: carrier timers of 1 ± 0.5 s, a 1.5 s
stand-in turn (longer than the timers, so canvases wait and are
replaced), and a 20-second rehearsal.

Each demo output is checked against the rehearsal's own timings and
receipt, which the test reads itself.

**Run with `--keep`**
- Every version made is drawn once, in order. Phase 2's marks appear as
  the voice's number under the cells it wrote.
- Each version's voice, turn, base and round trip match its timing row,
  to within 60 ms.
- The listed round trips are the blitted turns. The histogram counts
  them all, and its buckets add up.
- Each voice has a 60-column timeline, and its counts are the receipt's.
- The canvases that waited and those replaced (there are some) are the
  receipt's numbers, and the superseded canvases are the timings'.
- The receipt is shown.

**Through `run-phase-demo`**
- It offers phase 3 and runs it, with one stand-in word, so some turns
  change nothing (`u`). The voices' counts still match the receipt the
  demo prints.
- It leaves nothing in its temporary folder.

**In a pseudo-terminal** (`script`; skipped if missing): the marks are
colours, and again nothing is left behind.

    luajit src/045-test-phase-3-demo.lua [--dir ROOT]

It takes about forty seconds.
