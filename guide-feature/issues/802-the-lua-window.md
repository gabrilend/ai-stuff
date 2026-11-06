# 802 — The Lua window

phase 8, viewers for the desk and the browser

## Current behavior

The canvas is only text.

## Intended behavior

The recommended viewer: a desktop window (LuaJIT with SDL2 through its FFI,
or LÖVE, whichever the shared libs already support) drawing the canvas in a
monospace font at its exact size. Marked cells get their voice's colour
behind them, fading with age. When a new version arrives, the changed cells
are drawn writing over what was in that slot, over a fraction of a second,
so the eye catches each change.

Run options for driving it without a person: `--screenshot SECONDS` (saved
to `tmp/shared-memory/`, filed under `development-history/` by its run
script), `--key SECONDS NAME`, `--replay FOLDER`. Goodbye receipt: versions
received, frames drawn, seconds run.

## Suggested implementation steps

1. Check `/home/ritz/programming/ai-stuff/libs/` for an SDL or LÖVE setup
   other projects use.
2. Window, font, grid, marks, the write-over animation.
3. A scripted run on a replay with two screenshots, checked by looking.

## Related documents

- `docs/datapath-viewers.md`

## Blocked by

101, 202, 203.

## Blocks

804.
