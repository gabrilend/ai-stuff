# 301 — The transport: local and ssh

phase 3, the link

## Current behavior

Nothing exists.

## Intended behavior

One small set of operations the courier uses to reach the distant computer,
with two implementations chosen by `transport` in `input/link`:

| operation | `ssh` | `local` |
| --- | --- | --- |
| write a small file there | `ssh host 'cat > tmp && mv tmp path'` | write to a temporary name and rename, inside a stand-in folder |
| list a folder there | `ssh host ls` | list the stand-in folder |
| copy files in / out | `rsync` over ssh | `rsync` between folders |
| move a file there | `ssh host mv` | rename |
| git remote url | `ssh://host/path` | the stand-in clone's path |

The `local` transport has a **cut switch**: a file in
`tmp/shared-memory/link-cut` makes every operation fail as a dropped link
would. That lets tests and demos lose the connection on purpose.

Every operation returns success, or failure with the command's own error
text. There is no retry inside: retrying is the courier's choice.

## Suggested implementation steps

1. The operations table and its `local` entries, with tests.
2. The `ssh` entries, tested against `localhost` if an SSH server is
   running there, otherwise marked untested until phase 5.

## Related documents

- `docs/datapath-link.md`

## Blocked by

101.

## Blocks

302, 304, 402, 403.
