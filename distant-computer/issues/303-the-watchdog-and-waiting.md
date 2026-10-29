# 303 — The watchdog and waiting

phase 3, the link

## Current behavior

Nothing exists.

## Intended behavior

`scripts/watchdog` on the distant computer (`docs/datapath-link.md`, "The
watchdog's view"):

- every `check` seconds (`input/watchdog`) it reads `link/heartbeat`,
  compares its age with `waiting-after` (`input/link`), and writes
  `connected` or `waiting` into `link/state` (temporary name, rename);
- on each change of state it writes a ledger entry with the heartbeat's age;
- a missing heartbeat file is an error, not "waiting": it means the distant
  computer was never set up, which is a different problem from a lost link;
- it also provides a **may-touch** check for other programs: given a path,
  is it crystallized right now? (Always no while connected; while waiting,
  yes for the monorepo clone and every place in `input/crystallized`.)

## Suggested implementation steps

1. State from age, as a pure function, with tests at the boundary.
2. The loop and the ledger entries.
3. `input/crystallized` reading and the may-touch check, with tests for a
   folder line covering a file below it.

## Related documents

- `docs/datapath-link.md`

## Blocked by

101, 102.

## Blocks

305, 604.
