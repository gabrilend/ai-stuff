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
