# 104 — A proposal is applied as a diff

| | |
| --- | --- |
| Phase | 1 — The model, and the tools that read it |
| Blocked by | 102 |
| Blocks | 202 |
| Reads | [how a change is accepted](../../docs/003-how-a-change-is-accepted.md) |

## Current behavior

Proposals are specified and nothing reads them.

## Intended behavior

`apply-proposal ORG PROPOSAL` prints the proposal's derived status, its kinds
of change, who it affects and who has approved, each rule and whether it is
met, and the unified diff of `org.map` it would make. With `--write`, and only
when the status is ready, it writes the new map, carries the state across, and
appends `applied DATE` to the proposal. `--today DATE` fixes the date, so the
tool's answer is reproducible.

## Suggested implementation steps

1. Read the proposal file (P1–P6) with the shared reader.
2. The change id: FNV-1a over the change lines, in plain arithmetic that runs
   the same on LuaJIT and Lua 5.4.
3. Stale check, then apply to the map's lines exactly as document 003 orders.
4. Validate the result (broken), carry the state across.
5. Kinds and affected people per changed line; the rules (map's or default);
   approvals by latest answer, change ids honoured.
6. The front door, the diff by `diff -u`, `--write`.
7. Tests: both bakery proposals; a stale one; a broken one (one end of a wire);
   an approval whose change id no longer matches; routing around a producer
   without their consent; a rules change judged by the old rules.

## What Happened

Built as `src/010-proposals.lua`, with `./apply-proposal` as its front door and
`tests/011-proposals.lua` testing each of document 003's rulings, not only the
mechanism. Decisions made while building, each also written into document 003
where it sharpened the specification:

- **A `+`/`-` LINE is compared character for character** with the map's body
  line after its two spaces. Field-by-field comparison would let two spellings
  of one line both match, and then which one a proposal removed is a guess.
- **`+` lines go after the last body line the block still has**, so removing
  the last line of a block and adding a new one does not leave the addition
  stranded after the head.
- **Tidying happens only where something was removed.** Collapsing every
  double blank line in the file would put changes in the diff that nobody
  proposed.
- **An answer from somebody not in the org is not a problem** (P5): anybody can
  append a line to a file, and letting a stranger make a proposal invalid by
  doing so would be a way to block anything. It is shown and not counted.
- **A proposal by somebody not in the org, that does not add them, is
  invalid** (P2).
- **`--write` refuses anything but ready**, writes the state only when the org
  has one or the change produced one, and marks the proposal `applied` rather
  than moving it, so a proposal's path never changes under a link to it.
- **Exit status 3 means "not ready"**, distinct from 1 (an error), so a script
  can tell a waiting proposal from a broken map.
