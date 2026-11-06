# Phase 1 Progress — The spine

## Goals
Everything a run needs before there is anything to fight: configuration
defaults and overrides, named random streams, reading input/ at start and
writing the goodbye receipt at the end, the scripted-input timeline, the
headless runner and its multi-process batches, the screenshot filing, the
house-style linter, the test runner, and the documentation website.

The phase ends with a demo proving that a seed and a script decide a run
completely: `./run-phase-demo 1`.

## Completed Issues
- 101 — every knob has a default in one aligned table and a checked override.
- 102 — chance comes only from named streams made from the seed.
- 103 — a run starts from input/ and ends with the receipt in output/goodbye.
- 104 — input can be scripted on the simulated clock, through the real handlers.
- 105 — battles, duels and matches run headless; batches use every core.
- 107 — the house style is checked by `scripts/lint`.
- 108 — `./run-tests` runs the linter and every numbered test.

## Open
- 106 — screenshots are filed with notes and fingerprints; waits on the
  question of black frames from a covered window.
- 109 — the documentation website; not built; waits on where feedback goes.

Counts: `/home/ritz/programming/ai-stuff/scripts/progress-dashboard.lua <project> -m`.
