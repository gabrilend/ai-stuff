# Phase 2 Progress — The canvas for viewers

## Goals
Marks that let a person skim what changed (words and their sentences,
aging), the viewer-side reader, the canvas files with history, the HTTP
canvas server, and how the canvas size changes. Ends with two readers
receiving identical versions and the marks aging over a replay.
(`docs/roadmap.md`, phase 2)

Counts of done and open issues:
`/home/ritz/programming/ai-stuff/scripts/progress-dashboard.lua /mnt/mtwo/programming/ai-stuff/guide-feature -m`

## Completed Issues
(Each completed issue adds a line here saying what it built and how it
moves the phase toward its goals.)

- **201, marks for skimming** (2026-11-05): `src/020-marks.lua` marks
  every cell a blit wrote or blanked as a changed `word` and the rest of its
  sentence as `sentence`, in the voice and version that changed it. A cell
  keeps only its newest mark, and marks are dropped once over the mark
  lifetime. The blitter marks each version before publishing it, and logs
  and counts the marks. The viewer-side reader (202) and the canvas files
  (203) now have marks to carry.
- **202, the viewer-side reader** (2026-11-05): `src/022-viewer.lua` reads
  a canvas for viewers into a grid of cells, each with its character and
  its mark and the mark's age. It also gives the cells changed since the
  version drawn before, the error for a screen too small, and the voices'
  colour order. `assets/test-canvases/` holds canvases with the answers
  every viewer, in any language, must give. The two readers of the demo
  (206) and the Lua viewers (801, 802) read through it.
- **203, canvas files in RAM, with history** (2026-11-05): each version is
  written for viewers to `tmp/shared-memory/canvas/history/NNNNNN`, never
  rewritten, and to `canvas/current`, each by rename. The blitter now keeps
  only the current version in memory and reads its bases from the history.
  At start the folder is emptied, and version numbers carry on, even across
  a reboot, so an old base is refused, never mistaken. The HTTP server (204)
  and the file reader of the demo (206) have their files to serve and
  watch.
- **204, the HTTP canvas server** (2026-11-05): `src/025-canvas-server.lua`
  answers `GET /canvas`, `GET /canvas?after=N` (held open up to a minute)
  and `GET /canvas/N` from the canvas files, and nothing else. It is
  bounded in connections, request size and arrival time, and logs requests
  from outside the four machines. The demo's second reader (206) holds
  `?after=` requests on it. The encryption and the router's port wait for
  803 and the owner's machine.
- **205, one canvas for each screen** (2026-11-05): `src/028-screens.lua`
  plans a canvas per watched screen at its own size, largest first, in
  three modes (`round`, `asynchronous`, `smallest`, from `input/screens`),
  holds a context change until the round ends, and says what each screen
  shows meanwhile. `src/027-exact-shape.lua` builds each turn's
  lorem-ipsum example of the exact shape and cuts a reply too large;
  `viewer.layout` centres a smaller canvas. Running the turns and a
  blitter per canvas wait for 404, 405 and the display programs.
