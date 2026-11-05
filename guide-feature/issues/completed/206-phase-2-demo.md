# 206 — Phase 2 demo: two readers, marks aging

phase 2, the canvas for viewers

## Current behavior

The phase-1 demo exists once 108 is done.

## Intended behavior

`issues/completed/demos/phase-2-demo` runs the phase-1 series while two
readers watch, one on the canvas files and one holding
`GET /canvas?after=` requests. It shows:

- versions received by each reader, and that the two copies are byte for
  byte equal;
- how long each version took to reach each reader;
- the canvas drawn in the terminal with marks coloured by voice and dimmed
  by age, so the skimming idea can be seen before any real viewer exists;
- per version: cells marked `word`, cells marked `sentence`, marks expired.

## Suggested implementation steps

1. Two small reader scripts on the viewer-side reader (202).
2. The run script.
3. Fill in `issues/phase-2-progress.md`.

## Related documents

- `docs/roadmap.md`, phase 2

## Blocked by

202, 203, 204, 205.

## Blocks

None.

## Decisions (2026-11-05; each the owner's to overturn)

1. **Marks last three versions in the demo**, not the series' twelve, so
   the eight versions show marks aging and expiring (34 cells expire). The
   series is otherwise the phase 1 series, unchanged.
2. **The marks age over the series as it is played**, drawn from the
   readers' own copies, rather than a second pass over the history folder:
   they are the same versions, and the viewers' `--replay FOLDER` belongs to
   801 and 802.
3. **The two readers are separate processes**, support files beside the
   demo (`phase-2-file-reader.lua`, `phase-2-http-reader.lua`), each reading
   every version through the viewer-side reader (202). The files reader
   looks at `canvas/current`'s first line every 20 ms (no inotify binding
   yet). The HTTP reader holds one `?after=` request at a time.
4. **Every version is received, not only the newest.** When two versions
   are made between two looks, the files reader reads the missed one from
   `canvas/history`, and the HTTP reader asks `GET /canvas/N`. How each
   version came is shown (`current`, `history`, `first`, `wait`).
5. **"How long it took" is measured from the history file's time** (when
   the blitter wrote it, to the nanosecond the file system keeps) to the
   reader holding its copy. Version 1 is left out of the figures, because
   it was there before the readers started.
6. **Byte for byte means against `canvas/history` too**, not only the two
   copies against each other. The test reads the files itself rather than
   taking the demo's word.
7. **Marks in plain text are letters under each row**: the voice's place in
   the `voices:` header for a word mark, its letter (a, b, c) for a
   sentence mark. In a terminal they are background colours from the
   256-colour cube: red, green, blue for the three voices, a sentence mark
   at half a word mark's strength, fading to a quarter as it reaches the
   lifetime.
8. **The server runs on 127.0.0.1 and a free port**, checking for a new
   version every 0.05 s, in the throwaway project; the readers stop first,
   so the server's receipt shows the last held request abandoned.

## Implementation notes (2026-11-05)

- `issues/completed/demos/phase-2-demo` (also `./run-phase-demo 2`) and
  `phase-2-demo.lua`: the demo and its body.
- `issues/completed/demos/phase-2-file-reader.lua`,
  `phase-2-http-reader.lua`: the two readers.
- `src/030-test-phase-2-demo.lua`: 37 pass, about thirty seconds. `src/019`
  now accepts other phases beside phase 1 in `run-phase-demo`'s list.
- A run, plain: both readers received all 8 versions, identical to each
  other and to `canvas/history`; the files reader in 4 to 21 ms, the HTTP
  reader in 5 to about 100 ms. The HTTP figure is the server's: it notices
  a new version only when its `select` wakes (up to 0.1 s) and its check is
  due. Shortening that `select` to `check-seconds` would bring it near the
  files reader's; that is 204's to change, and it is left as it is.
- `.file-index-counter` is at 030.
- Mutation checks, 14, were each caught but one: either reader never
  reading a missed version, either copy altered by a byte, no dimming, a
  sentence mark as strong as a word mark, sentence marks as numbers, the
  lifetime not set, the word totals not summed, version 1 in the times, the
  unchanged turn not said, older marks not drawn, and the server stopped
  before the readers. The one not caught, the demo not comparing against
  `canvas/history`, changes nothing while the readers are right; the test
  compares the files itself.

**Checked here:** with LuaSocket, LuaJIT 2.1 and `script` (util-linux), on
127.0.0.1 only.

**Needs the owner's machine:** running it on kuvalu, and seeing the
colours in a real terminal.
