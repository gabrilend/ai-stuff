# 007-org-reader

Reads an org's files and refuses what breaks the org map's rules, by name.

## What it is for

Every tool in this project reads through here, so "what does this line mean"
has one answer. It implements [the org map](../docs/002-the-org-map.md): the
shared grammar (L1–L9), the map (M1–M15, warnings W1–W3), the state (S1–S4),
and the definitions of fed, ready, blocked and done.

**It names every problem, not the first.** One mistake — usually a wire changed
at one end — produces a family of complaints, and seeing the family is what
finds the cause. Each problem carries the file, the line and the rule code.

**It refuses rather than repairs.** A reader that quietly dropped a bad line
would leave a map meaning something different from what anybody reading the
text sees.

Run directly it is the validator; `./validate-org` is the front door.

## Exports

| Function | Returns |
| --- | --- |
| `read_org(dir)` | `{dir, map, state}`, problems, warnings |
| `read_map(text, file, dir)` | map, problems, warnings. `dir` nil skips M14. |
| `read_state(text, file, map)` | state, problems |
| `lex(text, file, problems)` | every line, classified, with fields; heads carry their body lines |
| `split_fields(s)` | fields and a parallel quoted-flag table, or nil and a message |
| `parse_body(head_kind, fields, quoted)` | one body line's record, or nil, code, message — shared with the proposal reader |
| `is_fed(org, box, port)` | whether an in port is fed |
| `box_state(org, box)` | `done`, `ready` or `blocked` |
| `is_name(s)`, `is_date(s)`, `day_number(date)` | the L7 and L8 checks, and a day count for date arithmetic |
| `format_problem(p)` | `file:line: CODE message` |
| `main(args)` | the validator's exit status |

## The map it returns

`map.org`, `map.persons[name]`, `map.outsides[name]` (with `speakers`),
`map.boxes[name]` (with `kind`, `holders`, `ins[port]`, `in_order`, `outs`,
`says`, `inside`), `map.rules[kind]` (with `approve[subject]` and `waits`), and
the `_order` lists that keep the file's order. `map.lines` is every line of the
file, and `map.blocks` every block with its head line, for tools that edit the
text.
