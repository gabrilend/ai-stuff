# 107 — The blitter loop

phase 1, the canvas and the blit

## Current behavior

Nothing exists. The blitter's place is described in
`docs/datapath-round-trip.md`, step 7.

## Intended behavior

The blitter as a running program on kuvalu, with no network yet:

1. Reads `input/blitter` (101): canvas size, merge mode, mark lifetime.
   Starts from an empty canvas, version 1.
2. Keeps every version in memory and in the history folder (203 adds the
   files; until then, memory only), because a voice's base must be found.
3. Watches `tmp/shared-memory/arrivals/`. It takes files in name order,
   reads each with the canvas reader (102), checks the sender in the file name
   against `voice:`, checks the size (105), looks up the base version, finds
   the changes (104) and blits (106).
4. A file that fails any check, or whose base is no longer in the history,
   is moved to `tmp/shared-memory/arrivals-refused/` with a log line naming
   the reason. A file that passes is deleted only after its blit.
5. If the canvas changed, makes the next version and hands it to each
   publisher in a list. In phase 1 the only publisher writes the canvas to the
   log. Files (203), rmail (303) and marks (201) are added later without
   changing the loop.
6. Merge modes are a dispatch table from mode name to a function. Phase 1
   has `newest`; `distill` (601) is added to the table.
7. On a clean stop (a signal, or a `stop` file in the arrivals folder),
   writes the goodbye receipt: arrivals taken, refused (by reason), turns
   skipped by rmail, versions made, words written, blanked, conflicts.

Waiting for files uses Linux inotify if a binding is available (rmail has
`rmail_inotify.c`), or else a once-a-second listing. Which one is used is
written to the log at start, because the listing is a fallback and must be
visible.

## Suggested implementation steps

1. Look for an inotify binding in `/home/ritz/programming/ai-stuff/libs/`,
   `my-libs/`, and rmail.
2. The loop, the refusal folder, the publisher list, the mode table, the
   stop file.
3. A test that drops a scripted series of voice canvases, including bad
   ones and stale bases, and checks the final canvas, the log and the
   goodbye.

## Related documents

- `docs/datapath-round-trip.md`
- `docs/datapath-blit.md`

## Blocked by

101, 102, 105, 106.

## Blocks

108, 203, 205, 302, 601.

## Decisions (2026-11-05; each the owner's to overturn)

1. **Arrivals are taken by the time in their names, then by name.** 302
   names them `<sender>-<unix time>-<random>`, so plain name order would take
   all of one voice's files before another's. `docs/datapath-round-trip.md`
   now says so.
2. **A name starting with `.` is a file still being written** (the hook's
   temporary name, 302), and `stop` is the stop file. Neither is an arrival.
3. **A signal stops it cleanly through `scripts/run-blitter`.** LuaJIT can't
   catch a signal, so the script catches INT and TERM and drops the stop file,
   which the loop already handles. A KILL writes no receipt: that is the crash
   report.
4. **The checks, in order:** name, readable, sender, turn newer than the
   voice's last, base in the history, size. The first failure is the reason.
5. **A turn no newer than the last one taken from that voice is refused**
   (`turn-not-newer`), equal included. A jump counts the turns rmail skipped.
   Only accepted arrivals move a voice's counter.
6. **`canvas-size` is fixed at start** (resizing is 205), and a change is
   logged. `merge-mode` and `collision-rule` are read again on every arrival.
   A file that stops reading while running keeps the last good settings,
   logged and counted, so a typo can't stop the canvas. A bad file at start
   stops it before it begins.
7. **The `collision-rule` setting** is a choice of the rules built (106).
8. **`distill` is a valid `merge-mode` in the file, but not built**, so an
   arrival in that mode is refused (`mode-not-built`), never quietly blitted
   as `newest`.
9. **There is no inotify binding.** I searched `libs/` and `my-libs/` in the
   monorepo and found none. rmail's `rmail_inotify.c` is on the owner's
   machine, outside this repository. So it lists the folder once a second,
   sleeping in `poll(2)`, and logs that at start. `opts.wait` is the seam
   where a binding would go.
10. **Every version is kept in memory**; 203 adds the files.
11. **The receipt's counters:** `arrivals-taken` counts every file, refused
    or not. `versions-made` doesn't count version 1, and
    `versions-in-history` does. The blit's counts are summed under their own
    names.
12. **A version's headers are `canvas`, `size`, `mode` and `written`.**
    `project` and `endpoint` come with the voices (303).
13. **`input/blitter` is in the repository** with the values to start with
    (60x20, `newest`, `blank-whole`, 12), each explained.
14. **A publisher is `function(blitter, record, report)`**, kept in a list;
    phase 1's writes each version, row by row, to the log.

## Implementation notes (2026-11-05)

- `src/016-blitter.lua`: a program and a library (`new`, `step`, `take`,
  `finish`, `main`, `MODES`, `SETTINGS`, `log_publisher`, `pending`).
- `scripts/run-blitter`: runs it, with INT and TERM as a clean stop.
- `input/blitter`: its settings.
- `src/017-test-blitter.lua`: 27 pass. It runs a scripted series with every
  refusal, the settings changing while it runs, the stop file and every
  receipt counter, then the real program stopped by TERM. Mutation checks
  (name order, the turn check, the sender check, no re-read, the stop file
  kept, temporary files taken) are each caught.
- A `.info.md` beside each source file. `.file-index-counter` is at 017.

**Checked here:** with LuaJIT 2.1 and jq on Linux.

**Needs the owner's machine:** running on kuvalu at
`/mnt/mtwo/programming/ai-stuff/guide-feature`, and an inotify binding if
one is wanted (rmail's `rmail_inotify.c`, copied in as `docs/vendored-code.md`
says).
