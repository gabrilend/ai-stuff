# 202 — The gate queue and its kinds

phase 2, the gate

## Current behavior

Nothing exists.

## Intended behavior

The near computer's gate module (`docs/datapath-gate.md`):

- **folders**: `tmp/shared-memory/gate/{incoming,waiting,answered,refused}/`;
- **admit**: take each file from `incoming/`, check it (201), and move it to
  `waiting/` with a `requested` ledger entry, or to `refused/` with a
  `failed` entry. An id already held anywhere in the gate is dropped
  (a repeat carry);
- **list** waiting requests, oldest first;
- **answer**: approved runs the kind's applier, then writes the answer file
  and the ledger entries; declined writes the answer and ledger entry only.
  An applier that fails leaves the request waiting, with a `failed` entry;
- **the kinds table**: kind → { reader, applier }.
  - `commit`: reader shows `git show --stat` and the diff of the fetched
    commit; applier cherry-picks onto `main` with the house own-lines
    commit tools, and records the new hash.
  - `write`: reader shows a diff against the current file; applier writes
    under a temporary name and renames.
  - `sudo`: reader shows the command; applier prints it and asks the owner to
    run it in their own terminal, then records the exit code they report.
    It never runs root commands in the background.
  - `outward`: reader shows the description; there is no applier. Approval
    records that the owner (or `by:`) will act; a later `applied` note is
    written by hand through `gate note`.
  - `decision`: reader shows the question and options; applier is nothing.
    The answer's note carries the choice.
- The monorepo root and the gate folders are passed in, so tests run on a
  throwaway git repository.

## Suggested implementation steps

1. Folders and admit.
2. List and answer, with the ledger.
3. Each kind's reader and applier, one at a time, each with a test on a
   throwaway repository.

## Related documents

- `docs/datapath-gate.md`, `docs/request-format.md`, `docs/ledger-format.md`

## Blocked by

102, 201.

## Blocks

203, 204, 302, 304.
