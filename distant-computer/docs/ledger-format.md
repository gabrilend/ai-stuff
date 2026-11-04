# The ledger

An append-only record of everything that crosses the gate. There is one on
each computer. The near computer's is the record of truth; the distant
computer's is the steward's own copy, for remembering what it asked and what
it was told.

## Where

    records/ledger          on the near computer, tracked in git
    records/ledger          on the distant computer, inside the steward's own
                            area, never pushed

## One entry

An entry is a block of `name: value` lines ending with a line holding a
single `.`:

    entry: 17
    time: 2026-10-28T23:14:05Z
    event: answered
    request: 20261028-231122-commit-7f3a
    answer: approved
    by: owner
    note: "looks right; the test covers it"
    prior: 9c1e...(64 hex digits)
    self: 4b07...(64 hex digits)
    .

| field | type | meaning |
| --- | --- | --- |
| `entry` | whole number | 1, 2, 3... with no gaps |
| `time` | text, UTC, ISO 8601 | when it was written |
| `event` | one word | `requested`, `answered`, `applied`, `failed`, `connected`, `waiting`, `note` |
| `request` | text | the request's id, when the event concerns one |
| (other fields) | text | depend on the event; listed with each event below |
| `prior` | 64 hex digits | the `self` of the entry before, or 64 zeros for entry 1 |
| `self` | 64 hex digits | SHA-256 of every line of this entry above `self:`, joined with newlines, plus the `prior` value |

Because each entry's `self` covers its `prior`, changing any byte of an
earlier entry breaks every checksum after it. The checker reports the first
entry where the chain breaks. That is the vision's "append-only memory,
backwards verified with checksums": the past can still be edited, but the
edit cannot hide.

## Events

| event | extra fields |
| --- | --- |
| `requested` | `kind`, `from` (which voice or program), `reason` |
| `answered` | `answer` (`approved`/`declined`), `by`, `note` (optional) |
| `applied` | `result` (one line: commit hash, path written, exit code) |
| `failed` | `error` (one line); the request goes back to waiting |
| `connected` / `waiting` | `heartbeat-age` (seconds) |
| `note` | `text` |

## Rules

- Only the ledger module writes the ledger. It holds a lock (a folder made
  atomically) while appending.
- The ledger is never rewritten. Starting a new one is done by renaming the
  old file to `records/ledger.<first-entry>-<last-entry>`, and the new
  file's entry 1 carries the old file's last `self` as its `prior`, so the
  chain runs across files.
