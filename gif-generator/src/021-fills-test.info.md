# 021-fills-test — proof for fill regions

Runnable directly (`luajit src/021-fills-test.lua [project-dir]`).
Proves: downward samples respect polygon and frontier; the opening
sliver neither starves nor strays from the top edge; full coverage
reaches the deep; at-once sampling spreads evenly (quadrant counts
within a stated 20%); radial stays inside its grown disc; along-
lines cover exactly their prefix while at-once lines are whole from
the first breath; a field track in a real timeline births hundreds
of particles, all inside the region; flat polygons, dot lines,
unknown sweeps, and timeless fills are refused. Exits nonzero on
failure.
