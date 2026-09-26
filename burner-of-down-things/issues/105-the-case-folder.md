# 105 — The case folder

One folder per piece of software, its record, and its lock
([003](../docs/003-datapath-the-case-and-the-ledger.md)).

## Current Behavior

There are no cases.

## Intended Behavior

- **Open** (name, source folder, harness): checks the name (lower-case words
  and dashes), that the source exists and is a folder, that no case has the
  name; makes `cases/<name>/` with `input/ output/ survey/ blueprint/issues/
  design/ turns/`; writes `case.lua` ([002](../docs/002-the-terms.md)); creates
  the ledger with `case-opened`.
- **Load** (name): reads `case.lua`, checks the ledger exists, returns the
  case table with its folder paths filled in.
- **Lock / unlock**: `lock` holds the process id and start time; taking it
  when present refuses, naming both (dead or alive — see 003).
- **Requests**: list `input/` files other than `target`, and say which are
  new (no `request-received` line names them).

| Decision | What each path leads to |
|---|---|
| Name taken, source missing, bad name | Refused, naming which |
| The source is inside `cases/` or inside this project | Refused: the machine does not describe itself into itself by accident. Surveying this project is done by copying it elsewhere first |

## Suggested Implementation Steps

1. Open and load. **Test:** open makes every folder and one ledger line;
   opening again refuses.
2. The lock. **Test:** a second lock refuses and names the first's id.
3. New requests. **Test:** two files in `input/`, one already named in the
   ledger; only the other is new; `target` is never a request.

## Blocked by

- 101
- 102
- 104
