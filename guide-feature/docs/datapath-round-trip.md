# Datapath: the canvas going out and coming back

The current design of one round. The issues that change it update this file.

## The path

    kuvalu                                        fg-sora-N
    ──────                                        ─────────
    blitter
      │ canvas version N
      ├──► tmp/shared-memory/canvas/current + history/   (viewers)
      └──► rewrites outbox/the-canvas (to: all three)
             │
    rmail (port 1223) ─────── encrypted ───────► rmail (10101 / 20202 / 30303)
                                                   │ on_receive (first) / on_update (later)
                                                   ▼
                                                 turn hook
                                                   │ newest canvas → tmp/shared-memory/turn/waiting
                                                   │ starts the turn runner if it is idle
                                                   ▼
                                                 turn runner (Lua)
                                                   │ one turn: look, ask, fit check
                                                   │ (docs/datapath-voice-turn.md)
                                                   ▼
                                                 rewrites outbox/canvas (to: guide)
                                                   │
    rmail ◄──────────────── encrypted ─────────────┘
      │ on_receive / on_update
      ▼
    arrival hook → tmp/shared-memory/arrivals/<voice>-<time>-<random>
      │
      ▼
    blitter: check, compare with the voice's base, blit (or distill)
      │      (docs/datapath-blit.md)
      └──► canvas version N+1 ... and round again

## Step by step

1. **kuvalu publishes version N**: to the RAM canvas folder for viewers, and
   as the body of `outbox/the-canvas` with one `to:` line per voice. Every
   file is written under a temporary name and renamed into place, so nothing
   ever reads half a file.
2. **rmail carries it** to each voice's `inbox/the-canvas`.
3. **The turn hook on the voice** receives it (`on_receive` the first time,
   `on_update` after that). It writes the canvas body to
   `tmp/shared-memory/turn/waiting`, replacing any canvas already waiting
   there, since only the newest matters. It then starts the turn runner in the
   background unless the runner's lock (a directory, made atomically) shows it
   is already running. It prints nothing and exits.
4. **The turn runner** takes the waiting canvas and runs one turn
   (`docs/datapath-voice-turn.md`). When the turn ends, it looks for a newer
   waiting canvas. If one is there it runs again, otherwise it removes its
   lock and exits.
5. **The edited canvas** is written into the voice's `outbox/canvas` with
   `base: N` and carried to kuvalu.
6. **The arrival hook on kuvalu** writes the body into
   `tmp/shared-memory/arrivals/`, prints nothing, and exits.
7. **The blitter** takes arrivals in order. It checks each one
   (`docs/canvas-format.md`, `docs/fit-check.md` for the size), looks up the
   voice's base version in the history, and blits or distills
   (`docs/datapath-blit.md`). If the canvas changed, the result is version
   N+1 and the round starts again from step 1.

A refused arrival is moved to `tmp/shared-memory/arrivals-refused/` with a
log line naming the reason. It is never dropped silently.

The blitter takes arrivals oldest first, by the unix time in their names
(`<sender>-<unix time>-<random>`), then by name. A name starting with `.` is
a file still being written; a file named `stop` is the blitter's clean stop
(issue 107).

## What lives where

| Data | Where | Type |
|---|---|---|
| the shared canvas, every version | kuvalu `tmp/shared-memory/canvas/` | text, `docs/canvas-format.md` |
| a voice's waiting canvas | voice `tmp/shared-memory/turn/waiting` | text |
| a voice's turn counter | voice, beside its mailbox (on disk, so a restart continues the count) | text, one number |
| a voice's edited canvas in flight | voice `outbox/canvas`, then kuvalu `inbox/` | text |
| arrivals waiting for the blitter | kuvalu `tmp/shared-memory/arrivals/` | text, one file each |
| logs | each machine's `tmp/shared-memory/*.log` | text lines |
| goodbye receipts | each machine's `output/goodbye-<program>` | text |

Everything under `tmp/shared-memory/` is RAM and is emptied by a reboot.
The blitter needs the history to find a voice's base. A voice whose base is
older than anything in the history (after a restart, for example) has its
canvas refused, and it is sent the current version. The history does
not survive a restart; the owner chose to keep it in RAM only. The version
numbers do carry on across restarts and reboots (`output/blitter-version`),
so an old base can never match a new version (issue 203).
