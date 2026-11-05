# 069-test-phase-6-demo — info

Tests `issues/completed/demos/phase-6-demo` (issue 602).

    luajit src/069-test-phase-6-demo.lua --dir ROOT

Its stand-in models and the rehearsal's mail listen on 127.0.0.1 only.
About two minutes: two demo runs record a half-minute rehearsal or replay.

- **The voices' stand-in model with `fill`** (047): an empty nth row
  started, a nth row's first word changed, and without `fill` the old
  behaviour.
- **A recording made by hand**: three arrivals, two voices writing on the
  same place from the same version and a third on its own row. Newest mode
  makes three versions, the second cutting into the first's word; distill
  mode makes two, the stand-in distiller keeping the first voice's word.
  The lines, the starred row, the `^` marks, the totals, what survived per
  voice and mode, the final canvases; a folder that is no recording is
  refused.
- **A recorded rehearsal, then the same recording replayed**: the
  recording saved, every arrival shown once in both modes, all three
  voices recorded, the distiller asked again after a reply past the edge,
  words written over in newest mode; replayed with `--from`, the same
  canvases and numbers (only the seconds differ); the throwaway copies
  removed; each recorded canvas saved with the version it started from;
  only the cells a version wrote marked.
- **The front door**: `run-phase-demo` offers phase 6.
