# 702 — Voice mailboxes

phase 7, the voices

## Current behavior

Nothing exists.

## Intended behavior

A way for the owner to talk to one voice, in either direction, outside of
requests: a mailbox per voice, carried by the courier like requests and
answers (`voices/<name>/to-owner/`, `voices/<name>/from-owner/`). The owner
reads and writes with `scripts/voice <name>`. Messages are plain text with
the time and sender in a header. They are not requests: nothing in a message
is ever applied.

## Suggested implementation steps

1. The two folders and a courier step for each.
2. The `voice` command (list, read, write, `-I`).

## Open questions

- Should this use rmail, which the house already has, instead of its own
  folders?

## Related documents

- `docs/datapath-link.md`

## Blocked by

302, 701.

## Blocks

703.
