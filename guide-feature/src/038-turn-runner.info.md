# 038-turn-runner — info

A voice's turn runner (issue 304), started by the turn hook (037) as
`scripts/turn-runner --mailbox FOLDER`. It takes the voice's lock, then
while `tmp/shared-memory/turn/<voice>/waiting` is there renames it to
`taken` and runs one turn on it; then it lets go of the lock, looks once
more, and exits.

One turn: the program named by `turn` in `input/turn-runner`, run as
`<turn> --dir ROOT --voice NAME --turn N --canvas FILE --out FILE`. Its
canvas is read back as from-voice and checked (voice, turn, base = the
canvas's version, size). Changed rows: written to the mailbox's
`outbox/canvas` (`to: <guide>`, a blank line, the canvas; a dot name, then
a rename) and the turn number kept in `output/turn-counter-<voice>`. No
change: nothing sent, the number kept. A failure: nothing sent.

The lock is `turn/<voice>/lock/pid`, `<pid> <start time>`, put in place by
renaming a ready directory. A holder not running (by `kill -0`, and by the
start time in `/proc/<pid>/stat` where there is one) is cleared with a log
line. Release removes only this process's lock.

Settings in `input/turn-runner`: `guide` (the contact), `turn` (the
program, from the project folder or a whole path). The receipt
`output/goodbye-turn-runner-<voice>` counts `turns-run`, `canvases-sent`,
`unchanged-turns`, `turns-failed`, `canvases-refused` and
`turns-gave-way`: a turn that exited 3, which the real turn (405) does when
`input/turn` says `newer-canvas = "give-way"` and a newer canvas came while
it was still asking. That sends nothing and keeps the turn number. Events go
to `turn/<voice>/events`: `<time> <event> <version> [turn]`, `gave-way`
among them.

| Function | Meaning |
|---|---|
| `run(root, mailbox, opts)` | the program; the turns run, or nil and why when the lock is held |
| `turn_once(ctx, run, taken)` | one turn: outcome, version, turn, log line |
| `take_lock(folder, note)`, `release(folder)`, `holder(folder)` | the lock |
| `alive(pid, start)`, `start_time(pid)`, `pid()`, `now()` | processes and time |
| `folder(root, voice)`, `counter_path(root, voice)`, `event(folder, ...)` | where things are |
