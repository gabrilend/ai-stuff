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

## Decisions (2026-11-05; each the owner's to overturn)

1. **No window yet; everything else is built.** The owner said no to raylib.
   Step 1's search found no SDL or LÖVE kept in the monorepo to copy: not in
   `libs/` or `my-libs/`, and RPG-autobattler has only scripts that would
   download one. Downloading a graphics library was ruled out for this
   build. So the window draws into its own picture (pixels in memory) and
   hands each frame to a backend; the one backend so far, `headless`, shows
   nothing and saves screenshots. A window backend has only to show that
   picture and pass on key presses (`M.BACKENDS` in
   `src/072-lua-window.lua` says what it must do).
2. **The letters are the monorepo's own 8x8 pictures**,
   `every-software-image-able/src/068-bitmap-font.lua`, copied unchanged
   into `libs/bitmap-font.lua` beside its `.upstream` note (the project's
   rule for reused code, `docs/vendored-code.md`). It is a monospace font
   that needs no font library and no font file on kuvalu. The eleven
   printable characters it has no picture for are drawn in its style in
   `src/072-lua-window.lua`, so the copy stays the same as its source. A
   letter beyond ASCII (é) is drawn as the font's hollow box, as that file
   insists: never a blank.
3. **Letters drawn twice their size by default** (`letter-scale = 2`, cells
   16x16 pixels): 8x8 is small on a desktop screen.
4. **The colour behind a cell is the voice's colour laid over the
   background** at a strength by mark kind and age (`word-strengths =
   "0.85 0.7 0.55 0.4 0.25"`, `sentence-strengths = "0.35 0.25 0.15"`), the
   same hues as the terminal view's red, green and blue, and kuvalu's
   magenta. Orphan marks count as sentence marks, as in the terminal view.
5. **A write-over run is one word's changed cells**, so "sat" to "ran" is
   written r, a, n left to right though the "a" did not change. Every run
   of a version is written at once, over `write-seconds = 0.4`: the eye
   sees every change start together, and a version with many changes takes
   no longer than one with few. Until a cell turns it shows the old
   character in the old colour.
6. **A version arriving before the last is written in full cuts it short**:
   the last is shown in full and the new one written over it, and the
   receipt counts it as `cut-short`. A replay or a busy run never falls
   behind the canvas.
7. **Frames are drawn only while something is being written** (30 a
   second); a still canvas costs nothing. The receipt's `frames-drawn`
   counts them.
8. **Screenshots are PNGs, written uncompressed**, so no library is needed
   and any image viewer opens them, each beside a text grid of the same
   frame for checking without looking. They are saved to
   `tmp/shared-memory/lua-window/screenshots/`; `scripts/lua-window` files
   them into `development-history/` when it stops, numbered after what is
   there, each with an `.info.md` (what made it, the commit, the date), the
   way neocities-modernization files its pictures.
9. **Keys**: `q` and `escape` stop, `space` pauses and resumes a replay, `s`
   takes a screenshot; any other key is logged. `--key SECONDS NAME`
   presses them; a window backend will pass on the real ones.
10. **`--fast` runs on a pretend clock**, drawing the same frames without
    the waiting, so tests and the phase 8 demo can replay a long history at
    once. `seconds-run` then counts the pretend seconds.
11. **`--replay` plays one version each `replay-every` seconds** (1.0) and
    stops once the last is written and the last scheduled screenshot or
    key is done; without `--replay` it watches `canvas/current` every
    `check-every` seconds (0.25), as the terminal view does.

## What was built (2026-11-05)

- `src/072-lua-window.lua`, `input/lua-window`, `scripts/lua-window`,
  `libs/bitmap-font.lua` and its `.upstream` note.
- `src/073-test-lua-window.lua`: 64 checks, the PNG read back pixel by
  pixel by the test's own reader; every one of 40 deliberate breaks of
  `072` is caught.
- Two screenshots of a replay looked at by eye: the colours, the letters,
  and "cat" half written over as "dat".
- `docs/datapath-viewers.md`, `docs/vendored-code.md`, `libs/README`; the
  phase 8 progress file.

## Needs the owner's machine

- **A window library on kuvalu**, and the backend for it, in
  `M.BACKENDS`: either SDL2 through LuaJIT's FFI (only `libSDL2` is needed:
  open a window of the picture's size, copy each frame's pixels into a
  streaming texture, present, and pass on key presses; no SDL2_ttf, since
  the letters are drawn already) or LÖVE (an `ImageData` from the pixels
  each frame). Which one is the owner's to choose; neither is kept in the
  monorepo yet. Then the window's own check: watch a rehearsal and look.
- **Letters beyond ASCII**: pictures for the accented letters the voices
  write (é, ö ...), added to `EXTRA_PICTURES`, or a font library in the
  window backend.
- The colours, strengths, letter scale and write speed tuned by eye on
  kuvalu's screen.
