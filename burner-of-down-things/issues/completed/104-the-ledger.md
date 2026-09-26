# 104 — The ledger

The append-only, chained record of a case
([003](../docs/003-datapath-the-case-and-the-ledger.md)).

## Current Behavior

Built as `src/016-ledger.lua`. A line's hash covers its first six fields *as written on disk* (escaped), so verification hashes bytes without re-escaping. `append` reads only the file's tail, doubling the window until the last line fits. `verify` reports the first failing line and which check failed: fields, seq, prev or hash. Checked by tests/023, including all three tamperings and constant-time appends to 20 500 lines.

## Intended Behavior

- **Append** (ledger path, kind, about, text): reads the last line's `seq`
  and `hash` (by reading the file's tail, not the whole file), builds the new
  line with the time, hashes it, and writes it with one append. Returns the
  new line as a table.
- **Verify** (ledger path): walks every line from the first; for each checks
  that `seq` is one more than the last, `prev` equals the last `hash`, and
  `hash` is the SHA-256 of the line's first five fields and `prev` joined by
  tabs. Returns ok, the line count and the head hash — or the first bad line's
  number, which check failed, and the expected and found values.
- **Read** (ledger path): every line as a table, for the center and the
  viewers.
- The ledger line's fields and escaping are those of
  [002](../docs/002-the-terms.md), written with the text-table module.

| Decision | What each path leads to |
|---|---|
| Append is asked of a ledger that does not exist | Refused; only opening a case creates one, by appending its first line to a new file through a separate create call |
| The kind is not in the kinds table | Refused, naming it. The kinds table is the list in 003; a new kind is added there first |
| Verify finds a bad line | Reported exactly; nothing is repaired |

## Suggested Implementation Steps

1. Create and append. **Test:** three appends; seq 1, 2, 3; each prev is the
   last hash; line 1's prev is 64 zeroes.
2. Verify. **Test:** a clean ledger passes; changing one character of line 5
   of 10 reports line 5 as a self-hash mismatch; recomputing line 5's hash
   too reports line 6 as a prev mismatch; deleting line 5 reports line 5 as a
   seq gap.
3. Tail reading. **Test:** append speed does not fall as the ledger grows
   from 1 000 to 100 000 lines.

## Blocked by

- 102
- 103
