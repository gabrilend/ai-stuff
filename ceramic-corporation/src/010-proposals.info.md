# 010-proposals

Reads a change proposal, applies it to the map as text, and says whether it may
be applied and why.

## What it is for

[How a change is accepted](../docs/003-how-a-change-is-accepted.md), made
executable. Nothing about a proposal is taken from what it says about itself:
its status, its kinds of change, the people it affects and whether the rules
are met are all computed from its lines and the map's. `./apply-proposal` is
the front door.

## Exports

| Function | Returns |
| --- | --- |
| `read_proposal(text, file, basename)` | the proposal (`name`, `by`, `opened`, `says`, `changes`, `answers`, `change_id`) and its problems (P1–P6, L) |
| `fnv1a(s)` | eight hex digits; plain arithmetic, the same on LuaJIT and Lua 5.4 |
| `apply_text(map, proposal)` | the new map text, or nil and the reasons it is stale |
| `carry_state(state, old_map, new_map)` | the new state text, and the lines that stopped being true |
| `kinds_and_affected(proposal, old_map, new_map)` | `{ kind -> set of people }` for every kind present |
| `answers(proposal, people)` | each person's standing answer, and whether it counts |
| `judge(proposal, old_map, by_kind, standing, today)` | per kind: who it affects, where the rule came from, and each check met or not |
| `evaluate(org, text, file, basename, today)` | the whole report, with `status` |
| `render(report)` | the report as text |
| `diff(old, new, label)` | a unified diff, by the system's `diff -u` |
| `main(args)` | 0 ready or applied, 3 not, 1 error, 2 usage |

## Things worth knowing

- **Applying edits the text, not a rebuilt file.** Lines the proposal does not
  touch are put back byte for byte, so the diff holds only the change.
- **The result is validated** with the same reader as any map; a proposal that
  changes one end of a wire is broken, by M12.
- **An objection from somebody the change does not affect** is printed as on
  the record and not blocking: the route-around rule, visible.
- **`--write` only writes a ready proposal**, and appends `applied DATE`
  rather than moving or deleting the file.
