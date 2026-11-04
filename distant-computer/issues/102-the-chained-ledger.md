# 102 — The chained ledger

phase 1, the record and the settings

## Current behavior

Nothing exists.

## Intended behavior

A Lua module that keeps the append-only record described in
`docs/ledger-format.md`:

- **append** an entry (an event name and a table of fields). It takes the
  lock (a folder made atomically), reads the last entry's number and `self`,
  writes the new entry with `prior` and `self`, and releases the lock.
- **read** entries one at a time, as tables, without loading the whole file.
- **check** the chain. It reads every entry, recomputes each `self`, and
  reports the first entry whose `self` or `prior` does not match, or that
  everything holds. Recomputing is independent per entry, given each
  entry's text, so the checker splits the file into ranges and hands one
  range to each worker (one per CPU core), then joins the results in order.
- **roll over** to a new file, carrying the chain across
  (`docs/ledger-format.md`, "Rules").

SHA-256 is computed in plain LuaJIT (bit operations), so the ledger needs no
outside program and the same code runs on both computers.

## Suggested implementation steps

1. SHA-256 in LuaJIT, tested against the standard test vectors.
2. The entry writer and reader (`name: value` lines, `.` terminator; values
   with spaces or quotes are written quoted).
3. Append with the lock.
4. The checker, single worker first, then split across workers using the
   house thread pool in `my-libs/threadpool` if it suits processes, or
   `luajit` child processes over ranges.
5. Roll-over.
6. Tests: a chain of 1000 entries checks clean; one changed byte is found at
   its entry; a removed entry is found; two appenders racing produce no gap.

## Related documents

- `docs/ledger-format.md`

## Blocked by

101 (the receipt; the checker is also a command).

## Blocks

103, 202, 302, 303, 603, 801.
