# 080-test-phase-8-demo — info

Tests `issues/completed/demos/phase-8-demo` (issue 804).

    luajit src/080-test-phase-8-demo.lua --dir ROOT

Its canvas servers listen on 127.0.0.1 only. About a minute: four demo
runs of ten seconds or so each, and the recorder.

- **The demo, kept** (a version each half second): each viewer's own log
  (terminal view, Lua window, the page's script in node) has versions 1 to
  8, each once, in order; the delays in the table, worked out again from
  those logs and the canvas files' own times, within 25 ms, each under a
  second; the receipts; the demo's server counting 127.0.0.1 as outside,
  the page signing in and asking for every canvas with its session, the
  demo's key outside its project at mode 600; every screenshot (the
  terminal's text and `.ansi`, the Lua window's PNG and text grid, the
  page's own drawing) showing version 8's characters as the viewer-side
  reader (022) reads the file; the side by side; the note filed beside.
- **Without node**: the page left out and said so, the other two still
  agreeing, exit 0.
- **Attached to a pretend live canvas folder**: a version written while it
  watches is drawn by all, the screenshots at it, and the folder holds
  only what the pretend live system wrote, still there afterwards.
- **Refused**: `--every` that is not seconds, a `--from` folder that is not
  there or has fewer than two canvases, a folder that is not the project,
  and a project from before the HTML page.
- **The front door**: `run-phase-demo` offers phase 8 and runs it; it files
  in `development-history/001-phase-8-demo` with its note, removes its
  throwaway copies and leaves nothing running.
- **The recording**: `phase-8-record.lua` makes `assets/phase-8-history`
  again, but for the `written:` lines; each file reads as its own version.
