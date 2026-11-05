# 016-blitter — info

The blitter (issue 107): the long-running program on kuvalu that takes the
voices' edited canvases from `tmp/shared-memory/arrivals/` and writes them
onto the shared canvas. Phase 1 has no network: arrivals are dropped in by
hand or by a script, and the only publisher writes each version to the log.

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
| `mode-not-built` | the merge mode in `input/blitter` is built |

Then the settings are read again, and the merge mode's function finds the
changes (104) and blits them (106). The file is deleted after its blit. If a
cell changed, that is the next version: kept in the history and handed to
each publisher. A jump in a voice's turns counts the turns rmail skipped.

## Settings, `input/blitter`

`canvas-size` (fixed at start; resizing is 205), `merge-mode` and
`collision-rule` (read again on every arrival), and `mark-lifetime` (for the
marks, 201). A file that no longer reads while running keeps the last good
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
`words-covered`, `cut-<outcome>`.

| Name | Type | Meaning |
|---|---|---|
| `new(opts)` | function | a blitter: settings read, run started, folders made, version 1 published. `opts.root`, `clock`, `publishers`, `wait` |
| `b:step()` | method | takes every arrival waiting; true when the stop file was there |
| `b:take(name)` | method | one arrival; `"blitted"`, `"unchanged"` or the refusal's reason |
| `b:finish()` | method | the goodbye receipt |
| `main(opts)` | function | steps and waits until a clean stop |
| `MODES`, `SETTINGS`, `log_publisher`, `pending`, `arrival_name` | | the mode table, the settings declared, the phase-1 publisher, the folder's order, a name's parts |

Tests: `017-test-blitter.lua`.
