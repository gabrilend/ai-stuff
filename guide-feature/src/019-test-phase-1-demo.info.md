# 019-test-phase-1-demo — info

Tests for the scripted series (018) and the phase 1 demo
(`issues/completed/demos/phase-1-demo`):
- every canvas the series makes reads back as a voice's canvas, with a name
  the blitter takes. Times and turns rise, one canvas is oversized, and one
  is on a stale base. A missing round, a missing base, or a write past the
  width is refused;
- the demo, run with `--keep --plain`, draws versions 1 to 8 at the canvas's
  real size. It marks the cells each version changed and shows each
  version's numbers. It shows the refusal with the fit check's report word
  for word, and the receipt counter for counter as the blitter wrote it. The
  log agrees with the receipt, the refused canvas is put aside, and the
  blitter has stopped;
- through `run-phase-demo`, the demo is plain when piped, gives the same
  canvas every time, and leaves no throwaway project behind. It refuses a
  folder that is not the project.

It takes about seventeen seconds, because the demo runs twice and the real
blitter waits a second between listings.

    luajit src/019-test-phase-1-demo.lua [--dir ROOT]
