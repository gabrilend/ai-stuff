# 104 — A proposal is applied as a diff

| | |
| --- | --- |
| Phase | 1 — The model, and the tools that read it |
| Blocked by | 102 |
| Blocks | 202 |
| Reads | [how a change is accepted](../docs/003-how-a-change-is-accepted.md) |

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
