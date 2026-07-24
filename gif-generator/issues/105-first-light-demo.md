# 105 — first-light demo (phase 1 capstone)

## Current Behavior

Canvas, palette, and encoder each pass their own tests but have never
been joined; no gif of ours has ever been watched.

## Intended Behavior

The phase-1 demo: a single glowing dot orbiting on black — no particle
system yet, just a hand-moved glow splat per frame — proving canvas →
tone-map → palette → encoder end to end.

- A demo script in `issues/completed/demos/` (phase-1) renders the
  orbit gif into `output/` and also into the demo's own directory,
  then opens it in a browser when a display is available; it prints
  the file size and frame count either way.
- The project root gains the phase-picker script: ask for a number
  1 through (completed phases), run that phase's demo. It reads which
  demos exist rather than hard-coding the count.
- The demo displays data, not description: frame count, bytes, bytes
  per frame, palette occupancy.

## Blockers

- 102 (light canvas), 103 (palette), 104 (encoder).

## Suggested Implementation Steps

1. A short orbit choreography written directly in Lua (angle stepped
   per frame, splat deposited, frame indexed and fed to the encoder).
2. The demo script with the DIR convention; stats printed from the
   actual emitted file, not from constants.
3. The root phase-picker script.
4. Watch it loop. This is the moment the project first exists.

## Related Documents

- docs/roadmap.md (phase 1)
- docs/architecture.md (the pipeline this proves)
