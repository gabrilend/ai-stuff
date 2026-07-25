# 017-easing-test — proof for easings and envelopes

Runnable directly (`luajit src/017-easing-test.lua [project-dir]`).
The property walk covers every registered curve in both tables —
pinned ends, kept bounds, forward-only motion — so a curve added
later cannot forget the contract. Spot-checks: the stroke lingers
below a fifth at halfway then snaps; ease-out mirrors it; envelopes
breathe, flash peaks at birth, hold holds; misspellings are refused
with the legal words taught back. Exits nonzero on failure.
