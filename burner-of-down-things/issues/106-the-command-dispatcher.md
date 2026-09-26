# 106 — The command dispatcher

The Lua entry point: one dispatch table of commands
([012](../docs/012-the-commands.md)), and the shape every run takes — read
`input/` first, take the lock, verify the ledger, work, write goodbye, let go.

## Current Behavior

`machine` has nowhere to go.

## Intended Behavior

- A table, one row per command: its name, the function that runs it, whether
  it needs a case, whether it needs the lock, a one-line description.
- For a command that needs a case: load it; read `input/` and append a
  `request-received` line for each new request (the first thing done); take
  the lock if the row says so; verify the ledger; run; write
  `output/goodbye` (what ran, what is waiting, what failed); append
  `goodbye`; unlock. The unlock and goodbye happen on failure too, the
  failure written into goodbye, and the machine exits non-zero.
- Commands in phase 1: `open`, `ledger`, `help`. Later phases add rows.
- The project's own `input/` is read at start (its files listed in the
  scratch log) and its `output/goodbye` written at the end, for every run.

| Decision | What each path leads to |
|---|---|
| Unknown command | The table printed; exit non-zero |
| The ledger fails verification | The run stops before its work, the finding in goodbye |

## Suggested Implementation Steps

1. The table and `help`. **Test:** every row has every field.
2. The run shape. **Test:** a command that raises an error still leaves
   goodbye, a `goodbye` ledger line, and no lock.
3. `open` and `ledger` as rows. **Test:** after `open`, the ledger holds `case-opened`
   then `goodbye`; `ledger` prints that count and a head hash that verify
   agrees with.

## Blocked by

- 105
