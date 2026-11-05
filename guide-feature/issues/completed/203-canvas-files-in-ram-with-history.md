# 203 — Canvas files in RAM, with history

phase 2, the canvas for viewers

## Current behavior

The blitter keeps versions in memory and publishes only to its log (107).

## Intended behavior

A publisher in the blitter's list writes each new version, with its marks,
to `tmp/shared-memory/canvas/current` (temporary name, then rename) and to
`tmp/shared-memory/canvas/history/NNNNNN`, never rewritten. The blitter
reads bases back from the history instead of holding every version in
memory.

At start the folder is emptied of the previous run. The owner chose that the
history does not survive a restart: after one, each voice's first canvas is
refused and it is sent the current version.

## Suggested implementation steps

1. The publisher, using the canvas writer (102).
2. The blitter's base lookup reading from history.
3. A test that runs a replay and checks the history has every version with
   no gaps, and that `current` equals the last.

## Related documents

- `docs/canvas-protocol.md`, "On kuvalu: files"

## Open questions

- None left.

## Blocked by

107, 201.

## Blocks

204, 206, 303, 801, 802.

## Decisions (2026-11-05; each the owner's to overturn)

1. **The files are written inside the blitter's publish step, not by a
   publisher in its list.** The blitter reads its bases back from the
   history, so no publisher list may leave the files out. Each version is
   written to `history/NNNNNN` first, then `current`, both under a `.` name
   and renamed. A history file that is already there is an error, never
   overwritten.
2. **The files are the text for viewers** (`for-viewers` headers), the same
   text the HTTP server (204) will send. That needs two settings in
   `input/blitter`: `project` (the project's name) and `voices` (the
   viewers' colour order). The commit in the `project:` header is read from
   git in the project root when the blitter starts (`opts.commit` in
   tests). Outside a git checkout it is written as `0000000`, and that is
   logged, rather than refusing to start.
3. **Only the current version is held in memory.** `b.history[n]` reads the
   file each time, and that is how bases are found. A base whose file is
   gone is refused as `base-not-in-history`.
4. **The history is emptied at start, as the owner chose. Version numbers
   are not reused.** A new run starts one past the previous run's last
   version. That version is read from the previous `current` and from
   `output/blitter-version`, a one-line file on disk written with each
   version, so the number outlives a reboot that empties the RAM. Without
   this, a voice's base from before a restart could match a new version of
   the same number and be blitted against the wrong canvas. With it, the
   voice's first canvas after a restart is refused, as the owner chose, and
   a viewer waiting for "a version above N" (204) still gets the next one.
   The new run's first version is the empty canvas.
5. **`versions-in-history` counts this run's versions** (last minus first,
   plus one), not the version number.
6. **The refusal names this run's versions** ("versions 9 to 9").

## Implementation notes (2026-11-05)

- `src/016-blitter.lua`: `write_files`; a history read from files;
  numbering carried on; the `project` and `voices` settings and the commit.
- `input/blitter`: `project` and `voices`. The tests' settings and the
  phase-1 series' settings (018) have them too.
- `src/017-test-blitter.lua`: its second run (stopped by TERM) now numbers
  on from 9, so its arrival is on base 9.
- `src/024-test-canvas-files.lua`: 26 pass.
- Mutation checks were each caught:
  - a history file rewritten;
  - no rename;
  - no zero padding;
  - numbering restarting at 1;
  - the folder not emptied;
  - bases not read from files;
  - the counter on the whole numbering;
  - the commit ignored;
  - the fallback commit;
  - the number on disk ignored;
  - the number in `current` ignored.

  Writing straight to the final names instead of renaming can't be told
  apart in a test with one process. The rename is there for a reader
  polling at the same moment.
- `docs/canvas-protocol.md`, `docs/datapath-round-trip.md` and the
  blitter's info file describe the files, the emptying and the numbering.
  `.file-index-counter` is at 024.

**Needs the owner's machine:** a run at
`/mnt/mtwo/programming/ai-stuff/guide-feature`, where the commit is read
from git.
