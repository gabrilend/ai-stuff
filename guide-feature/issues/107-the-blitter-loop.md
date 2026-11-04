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
