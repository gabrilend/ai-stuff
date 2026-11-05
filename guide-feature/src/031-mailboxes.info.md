# 031-mailboxes — info

Every rmail mailbox in the system, made one way (issue 301), from a
mailbox set: `input/mailboxes` for kuvalu's guide mailbox and the three
voices, or another set file (the rehearsal's stand-ins, 305).

    scripts/make-mailboxes [DIR] [--set FILE]
    luajit src/031-mailboxes.lua --dir ROOT [--set FILE]

A set's lines, for each mailbox NAME:

| Line | Type | Meaning |
|---|---|---|
| `NAME.folder` | text | where the mailbox is made; `~` is the home folder; never inside this project |
| `NAME.port` | whole | the port its daemon listens on, 1 to 65535 |
| `NAME.local-ip` / `NAME.ip` | text | its address on the home network / from anywhere; at least one |
| `NAME.hook` | choice | `arrival` (kuvalu, 302), `turn` (a voice, 304), `none` |
| `NAME.project` | text | guide-feature on that machine, for its hook |
| `NAME.contacts` | names | the mailboxes it talks to; either side naming the other makes one link |

Each mailbox folder gets `inbox/`, `outbox/`, `hooks/guide-hook` (runs the
project's `scripts/arrival-hook` or `scripts/turn-hook` with rmail's
arguments), a `config` (`name`, `port`, `auto_port_forward = false`,
`on_receive = ./hooks/guide-hook receive`, `on_update = ./hooks/guide-hook
update`), and a `contacts` file (600) with each linked mailbox's address,
port and the pair's secret: 32 random bytes as 64 hex digits, the same on
both sides, never printed.

A folder already there is adopted: secrets kept (and given to the other
side), missing lines added under a dated comment, and any line with another
value refused, naming both values, before anything is written.

| Function | Meaning |
|---|---|
| `read_set(path, source)` | `{ mailboxes, names, links }`, or an error naming the line |
| `build(set, opts)` | makes or adopts every folder; `opts.root`, `opts.now`, `opts.secret` |
| `read_config(path)` / `read_contacts(path)` | rmail's own files, read as rmail reads them |
| `secret()` | a new shared secret |
