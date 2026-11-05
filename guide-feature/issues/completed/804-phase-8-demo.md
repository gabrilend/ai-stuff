# 804 — Phase 8 demo: three viewers, one canvas

phase 8, viewers for the desk and the browser

## Current behavior

Earlier demos draw the canvas with demo scripts, not real viewers.

## Intended behavior

`issues/completed/demos/phase-8-demo` replays a recorded canvas history (or
attaches to the live system if it is up), opens the terminal view, the Lua
window and the HTML page in Firefox together, screenshots each at the same
version, and shows: versions drawn per viewer, delay from version published
to version drawn per viewer, and the screenshots side by side.

## Suggested implementation steps

1. The run script.
2. Fill in `issues/phase-8-progress.md`.

## Related documents

- `docs/roadmap.md`, phase 8

## Blocked by

801, 802, 803.

## Blocks

None.

## Decisions (2026-11-05; each the owner's to overturn)

1. **The recorded history is the phase 1 series through the real
   blitter**: 8 versions of the 40x6 kitten, dog and windy-day canvas,
   with marks of every age, in `assets/phase-8-history/`. Recorded once by
   `issues/completed/demos/phase-8-record.lua`, which makes it again (only
   the `written:` lines differ). It is replayed one version a second
   (`--every`), after 3 s for the viewers to start.
2. **Replayed as the blitter writes**: each version to `canvas/history`,
   then `canvas/current`, each by rename, into the demo's own throwaway
   canvas folder. The viewers are the real programs, unchanged, reading
   the live canvas as they would on kuvalu.
3. **"Attach to the live system"** is `--attach FOLDER` (kuvalu's
   `tmp/shared-memory/canvas`) for `--seconds` (30). The demo writes
   nothing to it: the throwaway copy's canvas folder is a link to it, and
   the demo's own canvas server only reads. It does not look for the live
   system by itself, so a demo run never touches it unasked.
4. **When a version was drawn** is each viewer's own log line, `drew
   version N at SECONDS` (the wall clock to the millisecond), added to
   070 and 072 for this; the page's is written by the page's own `follow`
   callback. **The delay** runs from the version's file being written
   (attached: its history file's time) to that line. The first version is
   left out of the delays: it was there before the viewers started.
5. **The HTML page goes the way a browser away from home goes.** The
   demo's canvas server counts 127.0.0.1 as outside the house, so the page
   signs in with a key made for the demo (kept beside the throwaway copy,
   mode 600, removed with it) and every canvas reaches it locked.
6. **The page's numbers come from its own script, in node**
   (`phase-8-page.js` takes the script from the server's `GET /` and runs
   its `follow` and `paint`). There is no browser on this machine and none
   was downloaded. **Its screenshot is Firefox's**, headless, at the
   page's `#demo:KEY:VERSION` address, where Firefox is installed;
   otherwise the page's own drawing, written as HTML with the page's own
   style, a span a cell with its colour, so the colours are still there to
   see. Without node the page is left out and the demo says so.
7. **The same version for all three** is the one the Lua window's
   screenshot caught (it shoots 1.5 s after the last version is written,
   time enough for every viewer to settle). The terminal view's screenshot
   is its last screen as written to the terminal (`.ansi`, and `.txt`
   without the codes); its size is fixed at 160x50 so it never depends on
   the terminal the demo runs in.
8. **Side by side** is printed as the characters inside each screenshot's
   frame, three columns, checked against the canvas file as the viewer-side
   reader (022) reads it; and filed as `side-by-side.html` with the
   pictures. The demo exits 0 only when every viewer that ran shows the
   canvas's own characters.
9. **Filed** in the next numbered `development-history/NNN-phase-8-demo/`
   with a note beside it, as the Lua window's screenshots are (`--out` to
   put them elsewhere).
10. **The phase 2 demo** writes the canvas server's new settings (803).

## What was built (2026-11-05)

- `issues/completed/demos/phase-8-demo` (the throwaway copy and clean-up)
  and `phase-8-demo.lua` (the run, the table, the side by side).
- `issues/completed/demos/phase-8-page.js`: the page's own script in node.
- `issues/completed/demos/phase-8-record.lua` and `assets/phase-8-history/`.
- `drew version N at SECONDS` log lines in `src/070-terminal-view.lua` and
  `src/072-lua-window.lua`.
- `src/080-test-phase-8-demo.lua`: 49 checks; all 26 deliberate breaks of
  the demo, its page helper, its recorder and the new log lines are caught.

A run here (one version a second):

    viewer         versions drawn    delay, written to drawn      screenshot
    terminal view  8 of 8            median 146 ms, longest 154 ms terminal-view.txt
    Lua window     8 of 8            median 180 ms, longest 187 ms lua-window.png
    HTML page      8 of 8            median 42 ms, longest 97 ms  html-page.html

All three showed version 8's characters, row for row.

## Needs the owner's machine

- **Firefox**: run the demo on kuvalu with Firefox installed; the page's
  screenshot is then Firefox's (`html-page.png`). Look at it beside the
  Lua window's.
- **The Lua window's real window** (802) is not part of this demo: it runs
  headless here, its screenshot drawn the same way the window will draw.
- **Attached to the live system**: `phase-8-demo --attach
  /mnt/mtwo/programming/ai-stuff/guide-feature/tmp/shared-memory/canvas`
  while a rehearsal or the real round runs.
