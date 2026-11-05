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
                                                   │ newest canvas → tmp/shared-memory/turn/<voice>/waiting
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
   ever reads half a file. kuvalu is the message's author, so every rewrite
   travels as an edit. Built in `src/035-to-voices.lua`, a publisher in the
   blitter's list, with its settings in `input/to-voices` (issue 303).
2. **rmail carries it** to each voice's `inbox/the-canvas`.
3. **The turn hook on the voice** receives it (`on_receive` the first time,
   `on_update` after that). It writes the canvas body to
   `tmp/shared-memory/turn/<voice>/waiting`, replacing any canvas already
   waiting there, since only the newest matters. It then starts the turn
   runner in the background unless the runner's lock (a directory, put in
   place in one step) shows it is already running. It prints nothing and
   exits. Only a message whose subject is `the-canvas` from the `guide`
   contact is taken. `<voice>` is the mailbox's own name, so voices sharing
   a project keep apart. Built in `src/037-turn-hook.lua`, run as
   `scripts/turn-hook` (issue 304).
4. **The turn runner** takes the waiting canvas and runs one turn
   (`docs/datapath-voice-turn.md`). When the turn ends, it looks for a newer
   waiting canvas. If one is there it runs again, otherwise it removes its
   lock and exits, and then looks once more, so a canvas that came in the
   moment before is not left waiting. A lock whose process is not running is
   cleared with a log line. Built in `src/038-turn-runner.lua`, run as
   `scripts/turn-runner`; in phase 3 the turn itself is the stand-in
   `scripts/stand-in-turn` (`src/039-stand-in-turn.lua`), named by
   `input/turn-runner`'s `turn` setting (issue 304).
5. **The edited canvas** is written into the voice's `outbox/canvas` with
   `base: N` and carried to kuvalu.
6. **The arrival hook on kuvalu** writes the body into
   `tmp/shared-memory/arrivals/`, prints nothing, and exits. Only a
   message whose subject is `canvas` is taken; anything else is logged and
   left alone. Built in `src/033-arrival-hook.lua`, run as
   `scripts/arrival-hook` (issue 302).
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
| a voice's waiting canvas | voice `tmp/shared-memory/turn/<voice>/waiting` | text |
| a voice's lock and events | voice `tmp/shared-memory/turn/<voice>/lock/pid`, `events` | text |
| a voice's turn counter | voice `output/turn-counter-<voice>` (on disk, so a restart continues the count) | text, one number |
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

## The rehearsal

`scripts/rehearse` (`src/043-rehearsal.lua`, issue 305) runs this whole
path on kuvalu before any mini-computer is set up.

**What it sets up**
- Four mailboxes in RAM, made by `scripts/make-mailboxes`: the guide, and
  `fg-sora-1` to `-3` with the turn hook and the stand-in turn.
- The blitter mailing every version.
- The mail carried between the mailboxes by rmail's rules, either:
  - by the stand-in carrier (`src/041-stand-in-carrier.lua`), on this
    machine only, with rmail's timers; or
  - on the owner's machine, by real rmail daemons.

**What it times, for every voice turn**

| Stage | When |
|---|---|
| published | the version was written to the guide's outbox |
| received | the voice's hook left it waiting |
| taken | the voice's turn runner took it |
| finished | the voice's canvas was in its outbox |
| delivered | it was carried to kuvalu |
| arrived | it was in `arrivals/` |
| blitted | the blitter took it |
| back | the voice received the version its turn made |

The timings are written to `tmp/shared-memory/rehearsal-timings`, and
every event to `rehearsal-events`.

A turn whose canvas was replaced in the voice's outbox by its next turn's,
before rmail carried it, is `superseded`. Only the newest version of a
living message travels.

It stays the test bench for the real turn (405) and distill mode (601).

