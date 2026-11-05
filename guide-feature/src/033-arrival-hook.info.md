# 033-arrival-hook — info

kuvalu's arrival hook (issue 302), set as both `on_receive` and
`on_update` in the guide mailbox through its `hooks/guide-hook` (031),
which runs `scripts/arrival-hook` with a first word from the config line:

    arrival-hook receive <sender> <subject> <inbox file>     on_receive
    arrival-hook update  <sender> <inbox file> <new body>    on_update

It writes the body to `tmp/shared-memory/arrivals/<sender>-<unix
time>-<random>` (a dot name, then a rename), prints nothing and exits.
`on_update`'s subject is its inbox file's name; only `canvas` is taken,
anything else is logged and left alone, as is a sender that is not a plain
name. An empty `<new body>` (rmail #215, a body over 64 KiB) is read from
standard input. The RAM tiers are made sure of first, since a reboot
empties them.

| Exit | When |
|---|---|
| 0 | written, or left alone on purpose |
| 1 | not a call it takes, an inbox file it cannot read, an empty body, or nowhere to write (under rmail #215 the edit is refused and sent again) |

One line per call goes to `tmp/shared-memory/arrival-hook.log`.

| Function | Meaning |
|---|---|
| `arrive(root, args, stdin, now)` | one call: the exit status and the log line |
