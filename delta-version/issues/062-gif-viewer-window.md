# Issue 062: A Window for Watching the Gifs

**Status**: In progress (built and tested; waiting on the owner trying it and
on the open question below)
**Priority**: Medium
**Created**: 2026-09-26
**Type**: New tool (`scripts/gif-viewer/`, a LÖVE program)
**Related**: `060-readme-gallery-of-interacting-shapes.md` (the renderer that
makes the gifs)

---

## Current Behavior

**Built (2026-09-26).** Steps 1–6 are done, in `scripts/gif-viewer/`.

- **Launch:** `view-gifs` opens the window on the shape gifs.
- **Load time:** all 29 load in the self-test: 1,980 grid frames, plus the
  first gif's 144 full frames.
- **Decode speed:** about a quarter of a second for the largest file,
  216 frames.
- **Tests:** 19 of 19 reader checks pass, and the window test saves a
  picture of each view.
- **Found while building:** LÖVE's built-in font has no arrow symbols, so
  the key hints are written in words.
- **The owner's report** that the gifs "can't load" in their viewer was
  checked:
  - feh (`feh -l`), ImageMagick and ffmpeg all read every file, with no
    errors, and agree on the frame counts.
  - feh shows only a gif's first frame, never an animation, which may be
    what was seen. mpv plays them.

**Before this issue** — the shape gifs live in `/home/ritz/pictures/shape-gifs/`, about thirty of
them. The only way to watch them is a web browser, one file at a time, or
all at once in tabs. Nothing shows them together or lets the owner step
through them with the keyboard.

## Intended Behavior

A small LÖVE (LuaJIT) program that opens a black window on a folder of
gifs:

| Key | Does |
|-----|------|
| ← / → | the previous / next gif |
| space | the next gif |
| g | switch between one gif and a grid of all of them, every cell animating |
| esc, q | quit |

In the grid, the arrow keys move a highlight, and enter or a mouse click
opens the highlighted gif (an addition; the owner's keys are unchanged).

**Decoding.** LÖVE reads only a gif's first frame, so the viewer carries its
own decoder. It is written for any gif, not just this renderer's output:

- local colour tables, not only the global one;
- frame rectangles smaller than the screen;
- transparency and the disposal rules;
- interlaced frames.

That way any gif dropped into the folder plays.

**Parallel.** Decoding thirty files of a hundred-plus frames each is real
work. It runs in LÖVE worker threads, one per core but one, so the window
stays responsive. The gif on screen, and its neighbours, are decoded first.

**Memory.** Every frame of every gif at full size would be over a
gigabyte. So:

- **The single view** keeps full-size frames for a few gifs at a time: the
  current one and its neighbours, evicting the least recently seen.
- **The grid** uses small copies, shrunk once at decode time, keeping every
  second frame with its delay doubled. The grid's timing still matches the
  original.

## Suggested Implementation Steps

1. **Decoder** (`gif-decode.lua`): plain LuaJIT with ffi and no LÖVE, so it
   can be tested on its own. It turns a gif's bytes into its width, height,
   and a list of frames, each a full RGBA picture plus its delay.
2. **Worker** (`decode-worker.lua`): takes requests (a path, a size) from a
   channel, decodes, and fills LÖVE ImageData objects through their raw
   memory. It sends them back one frame at a time, so the main thread can
   turn them into textures a few per tick instead of stalling.
3. **Window** (`main.lua`, `conf.lua`):
   - the key table as a dispatch table;
   - playback by each frame's own delay;
   - the name of the gif shown under it, with a loading marker while it
     decodes;
   - scaling to fit the window, sharp-edged (nearest neighbour).
4. **Launcher** (`view-gifs`): a bash script with the folder hard-coded,
   `/home/ritz/pictures/shape-gifs/`, and overridable by an argument.
5. **Test** (`test-gif-viewer.sh`), which runs the decoder without LÖVE:
   - decode every gif in the folder, and check the frame count and size
     against an independent block walker (the gallery's `gif-facts.lua`);
   - round-trip frames through gif-generator's encoder and compare every
     pixel;
   - check a hand-built gif with a local colour table, a sub-rectangle,
     transparency and interlacing.
6. **Document** (`gif-viewer.info.md`).

## Open questions

- Should the grid show every gif in the folder, or also the PNG stills in
  `stills/`? (Default: gifs only.)
