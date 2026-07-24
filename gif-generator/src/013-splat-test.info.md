# 013-splat-test — proof for the snapshot and splatter

Runnable directly (`luajit src/013-splat-test.lua [project-dir]`).
Proves: a centered stamp is fourfold symmetric with its heart
brightest; coincident particles sum exactly; edge particles clip by
bounds and still land what fits; a half-pixel shift changes the
light and leans it the way it moved; a real simulated swarm renders
identically from pool and from snapshot to the last float (the
assertion that caught fade's precision being shaved at the border);
an undersized snapshot refuses. Exits nonzero on failure.
