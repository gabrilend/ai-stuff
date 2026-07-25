# 023-score-test — proof for the score module

Runnable directly (`luajit src/023-score-test.lua [project-dir]`).
Proves: both shipped reference scores read (shapes tagged, tip
landmarks intact); structural walls refuse missing canvases, double
canvases, empty scores, and scores that compute; the walk-back
insertion sorts shuffled times and keeps arrival order at ties; the
canonical writer is a fixed point (write, read, write —
byte-identical) and carries comments above their strokes. Test
scores land in RAM scratch, never the project. Exits nonzero on
failure.
