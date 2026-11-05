# 016-blitter — info

The blitter (issue 107): the long-running program on kuvalu that takes the
voices' edited canvases from `tmp/shared-memory/arrivals/` and writes them
onto the shared canvas. Phase 1 has no network: arrivals are dropped in by
hand or by a script, and the only publisher writes each version to the log.
Run as a program, it also mails each version to the voices (303,
`src/035-to-voices.lua`), as `input/to-voices` says.

    luajit src/016-blitter.lua [--dir ROOT]
    scripts/run-blitter [ROOT]      Ctrl-C or TERM stops it cleanly

## One arrival

Taken oldest first: by the unix time in its name
(`<sender>-<unix time>-<random>`, issue 302), then by name. Names starting
with `.` are still being written, and `stop` is the stop file. Each is
checked in this order, and the first failure moves it to
`tmp/shared-memory/arrivals-refused/` with a log line and a counter:

| Reason | Check |
|---|---|
| `bad-name` | its name is `<sender>-<unix time>-<random>` |
| `unreadable` | the canvas reader (102) reads it as a voice's canvas |
| `wrong-sender` | its `voice:` header is the sender in its name |
| `turn-not-newer` | its turn is after the last one taken from that voice |
| `base-not-in-history` | its base version is in the history |
| `wrong-size` | it is the size of its base (105's `arrival`) |
| `mode-not-built` | the merge mode in `input/blitter` is built (both are, since 601) |

Then the settings are read again, and the arrival is kept as its voice's
newest (`b.newest[voice]`: its canvas, base, turn, and the changes found
against its base, 104). In `newest` mode the mode's function blits those
changes (106). In `distill` mode (601) the arrival is held instead, and
after the arrivals waiting are taken `b:distill_held()` has the distiller
(`src/067-distill.lua`) make one canvas from every voice's newest, which is
blitted onto the current canvas under the name `kuvalu`; see
`docs/datapath-blit.md`, "distill", "As built". The file is deleted after its blit. If a
cell changed, that is the next version. It is marked (201,
`src/020-marks.lua`) and written as viewers read it (203) to
`tmp/shared-memory/canvas/history/NNNNNN` and `canvas/current`, each under a
`.` name and renamed. Then it is handed to each publisher, so every
publisher gets the version with its marks, as `publisher(blitter, record,
report, voice)` (report and voice are nil for version 1). The log gets a `marks:` line of
counts for it.

## The history, and restarts

Only the current version is held in memory. `b.history[n]` reads version n
back from its file, and that is where each voice's base is found. At start,
the canvas folder is emptied of the previous run. Numbering carries on from
the previous run's last version, read from `current` and from
`output/blitter-version` (on disk, written with each version), so no number
is ever used twice. A base from before the restart is refused as not in the
history. The `project:` header's commit comes from git in the root
(`opts.commit` in tests). Outside a git checkout it is written as `0000000`,
and logged. A jump in a voice's turns counts the turns rmail skipped.

## Settings, `input/blitter`

`canvas-size` (fixed at start; resizing is 205), `merge-mode` and
`collision-rule`, `mark-lifetime`, `project` and `voices` (read again on
every arrival; a mark is dropped once it is more than `mark-lifetime`
versions old; `project` and `voices` are the viewers' headers). A file that no longer reads while running keeps the last good
settings, and the error is logged and counted. A bad file at start stops it
before it begins.

## Stopping

A file named `stop` in the arrivals folder: the arrivals before it are
taken, it is removed, and the goodbye receipt is written. LuaJIT can't catch
a signal, so `scripts/run-blitter` catches INT and TERM and drops the stop
file. A KILL writes no receipt, which is the crash report.

## Waiting

There is no inotify binding in this project, so it lists the folder once a
second, sleeping in `poll(2)`, and says so in the log at start. `opts.wait`
is the seam where a binding would go.

## The receipt

`arrivals-taken` (every file, refused or not), `refused-<reason>`,
`versions-made` (after version 1), `versions-in-history`, `turns-skipped`,
`unchanged-turns`, `voice-marks-ignored`, `settings-not-read`, and the
blit's counts summed: `words-written`, `removals-applied`, `conflicts`,
`words-covered`, `cut-<outcome>`; and the marks' counts, in cells:
`cells-marked-word`, `cells-marked-sentence`, `marks-expired`. Distill mode
(601): `arrivals-held`, `held-replaced`, `distills`, `distills-failed`,
`unchanged-distills`, `distill-asks`, `distill-tries`,
`distill-milliseconds` (the distiller's time, summed).

| Name | Type | Meaning |
|---|---|---|
| `new(opts)` | function | a blitter: settings read, run started, folders made, the canvas folder emptied, the first version published. `opts.root`, `clock`, `publishers`, `wait`, `commit`, `distill_call` (tests: stands in for the distiller) |
| `b:step()` | method | takes every arrival waiting, then distills what was held; true when the stop file was there |
| `b:take(name)` | method | one arrival; `"blitted"`, `"unchanged"`, `"held"` or the refusal's reason |
| `b:accept(sender, voice, base, name)` | method | an arrival past its checks, in the mode now set (the phase 6 demo replays recorded arrivals through it) |
| `b:distill_held()` | method | the distill, when anything is held: `"blitted"`, `"unchanged"` or `"failed"`, the entries taken in and those they replaced; nil when nothing is held |
| `b:finish()` | method | the goodbye receipt |
| `main(opts)` | function | steps and waits until a clean stop |
| `MODES`, `HELD`, `SETTINGS`, `log_publisher`, `pending`, `arrival_name` | | the mode table, the modes that hold arrivals, the settings declared, the phase-1 publisher, the folder's order, a name's parts |
| `distiller` | table | 067, replaceable |

Tests: `017-test-blitter.lua`, `068-test-distill.lua`.
