# Phase 8 Progress — Viewers for the desk and the browser

## Goals
Terminal view, Lua window, HTML page, all reading only the canvas
protocol. Ends with all three on the same version, screenshotted.
(`docs/roadmap.md`, phase 8)

Counts of done and open issues:
`/home/ritz/programming/ai-stuff/scripts/progress-dashboard.lua /mnt/mtwo/programming/ai-stuff/guide-feature -m`

## Completed Issues
- **801 the terminal view** (2026-11-05): `scripts/terminal-view` draws the
  canvas in any terminal, reading only `canvas/current` through the
  viewer-side reader: a thin border at the canvas's size, each voice's
  colour, word marks bright and sentence marks dim, stepping down with age
  (`input/terminal-view`), redrawn when a new version is written, the
  too-small error naming both sizes. Checked against reference screens of
  the shared test canvases (`src/071-test-terminal-view.lua`).
- **802 the Lua window** (2026-11-05), all but the window: the canvas drawn
  as a picture with the monorepo's own 8x8 letters, each voice's colour
  behind its cells fading by age (`input/lua-window`), each changed word
  written in left to right over the old over 0.4 s. `scripts/lua-window`
  runs it headless for now: `--replay`, `--screenshot` (a PNG and a text
  grid, filed into `development-history/`), `--key`, `--fast`. The window
  itself waits for SDL2 or LÖVE on kuvalu (the issue's "Needs the owner's
  machine"). Checked by `src/073-test-lua-window.lua`.
