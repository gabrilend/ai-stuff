# 602 — The Lua window

phase 6, viewers for the desk and the browser

## Current behavior

Pages are only text.

## Intended behavior

The recommended viewer: a desktop window (LuaJIT with SDL2 through its FFI,
or LÖVE, whichever the shared libs already support) that draws the display
box in a monospace font. Each thought's opacity follows its relevance, and a
thought that dropped or vanished between pages fades over a second rather
than blinking out.

Run options for driving it without a person: `--screenshot SECONDS` (saved
to `tmp/shared-memory/`, and filed under `development-history/` by the run
script), `--key SECONDS NAME`, `--replay FOLDER` (draw a history folder
instead of the live page). Goodbye receipt: pages received, frames drawn,
seconds run.

## Suggested implementation steps

1. Check `/home/ritz/programming/ai-stuff/libs/` for an SDL or LÖVE setup
   other projects use.
2. Window, font, box, opacity, fade animation.
3. A scripted run with a replay and two screenshots, checked by looking.

## Related documents

- `docs/datapath-viewers.md`

## Blocked by

101, 202, 203.

## Blocks

604.
