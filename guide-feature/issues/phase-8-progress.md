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
- **803 the HTML page** (2026-11-05): `GET /` on the canvas server is one HTML
  file with inline JavaScript. It signs in with `#NAME:KEY` in its address,
  or a viewer's name and password, holds `/canvas?after=N` open in a
  session, unlocks each version (AES-256-GCM, noble-ciphers) and draws it
  with the Lua window's colours, fading each changed letter in. Outside the
  four machines the canvas is never sent plain. `scripts/add-viewer` sets a
  viewer up. Checked by `src/075-test-crypto.lua` and
  `src/078-test-html-page.lua` (with `079-test-html-page.js` in node). The
  look in Firefox waits for the owner's machine.
