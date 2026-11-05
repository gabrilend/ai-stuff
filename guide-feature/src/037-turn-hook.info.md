# 037-turn-hook — info

A voice's rmail hook (issue 304), set as both `on_receive` and `on_update`
in the voice's mailbox through its `hooks/guide-hook` (031), which runs
`scripts/turn-hook` with a first word from the config line:

    turn-hook receive <sender> <subject> <inbox file>     on_receive
    turn-hook update  <sender> <inbox file> <new body>    on_update

It writes kuvalu's canvas to `tmp/shared-memory/turn/<voice>/waiting` (a
dot name, then a rename), replacing a canvas already waiting, then starts
the turn runner (038) detached, unless the voice's lock is held by a
running process. It prints nothing and exits at once. `<voice>` is the
`name` in the config of the mailbox holding the inbox file (a relative
path is taken from where rmail runs). `on_update`'s subject is the inbox
file's name, a `-from-<sender>` ending taken back off. Only subject
`the-canvas` from the
`guide` contact of `input/turn-runner` is taken; anything else is logged
and left alone. An empty `<new body>` (rmail #215) is read from standard
input.

| Exit | When |
|---|---|
| 0 | left waiting, or left alone on purpose |
| 1 | not a call it takes, an inbox file it cannot read, an empty body, unreadable settings, a file in no mailbox's inbox, or nowhere to write (under rmail #215 the edit is refused and sent again) |

One line per call goes to `tmp/shared-memory/turn-hook.log`; `received`
and `replaced` go to `turn/<voice>/events`.

| Function | Meaning |
|---|---|
| `call(root, args, stdin, opts)` | one call: the exit status and the log line; `opts.start` replaces starting the runner |
| `start_runner(root, mailbox)` | `setsid scripts/turn-runner --mailbox M`, output to /dev/null, in the background |
