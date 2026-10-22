# 107 — The page keeper's loop over the arrivals folder

phase 1, the fit and the fade

## Current behavior

Nothing exists. The page keeper's place in the system is described in
`docs/datapath-frame-to-page.md`, steps 4–6.

## Intended behavior

The page keeper as a running program on kuvalu, with no network yet:

1. Reads `input/page-keeper` (101).
2. Watches `tmp/shared-memory/arrivals/`. It takes files in name order,
   reads each with the frame reader (102), checks the sender in the file name
   against the frame's `voice`, runs the fit check (103) against the current
   share, and applies it to the ledger (105).
3. A file that fails any check is moved to
   `tmp/shared-memory/arrivals-refused/` with a log line naming the reason.
   A file that passes is deleted only after it is in the ledger.
4. After each arrival, lays out the page (106). If the page changed, it hands
   the page record to whatever publishers are configured. In phase 1 the only
   publisher writes the page record to the log. Phase 2 adds files and HTTP,
   phase 3 adds rmail. The publishers are a list of functions, so adding one
   does not change the loop.
5. On a clean stop (a signal, or a `stop` file in the arrivals folder),
   writes the goodbye receipt: frames taken, frames refused (by reason),
   frames skipped by rmail, pages built, thoughts carried, crossed between
   voices, vanished, rows hidden by the box.

Waiting for files uses Linux inotify if a Lua binding is available in the
shared libs, otherwise a once-a-second listing. Which one is used is written
to the log at start, because a poll is a fallback and must be visible.

## Suggested implementation steps

1. Look in `/home/ritz/programming/ai-stuff/libs/` and `my-libs/` for an
   inotify binding (rmail has `rmail_inotify.c`, which may be reusable).
2. The loop, the refusal folder, the publisher list, the stop file.
3. A test that drops a scripted series of frames, including bad ones, and
   checks the log and the goodbye receipt.

## Related documents

- `docs/datapath-frame-to-page.md`

## Blocked by

101, 102, 103, 105, 106.

## Blocks

108, 203, 302.
