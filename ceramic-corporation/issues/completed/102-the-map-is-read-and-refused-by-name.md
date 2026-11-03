# 102 — The map is read, and refused by name

| | |
| --- | --- |
| Phase | 1 — The model, and the tools that read it |
| Blocked by | 101 |
| Blocks | 103, 104, 105, 106 |
| Reads | [the org map](../../docs/002-the-org-map.md) |

## Current behavior

The format is specified and nothing reads it.

## Intended behavior

One reader, shared by every tool, that turns `org.map`, `org.state` and a
proposal into tables, and a validator that checks every L, M and S rule. A
refusal names the file, the line number, the rule code and what is wrong — and
names **every** problem, not the first, because one mistake usually produces a
family of complaints and seeing the family is what finds the cause. Warnings
(W1–W3) are printed and do not fail.

A root script, `validate-org`, takes an org directory and exits 0 when the org
is valid.

## Suggested implementation steps

1. A line splitter for the shared grammar (L1–L9): blank, comment, head, body;
   fields with quoted strings.
2. A map reader building persons, outsides, boxes (with ports and holders) and
   rules, recording each line's number.
3. The M checks, both-ends (M12) last because it needs every box.
4. The state reader and S checks.
5. The definitions from "what the files mean": fed, ready, blocked, done.
6. `validate-org`, the Bash front door, with the hard-coded `DIR` and the
   override.
7. Tests: the bakery is valid; one broken file per rule code, each refused
   with that code.

## What Happened

Built as `src/007-org-reader.lua`, with `./validate-org` as its front door and
`tests/009-the-map-and-the-board.lua` refusing one smallest broken file per
rule code. Decisions made while building:

- **The reader and the validator are one module.** Every check is something a
  reader must refuse anyway; a separate validator would be a second reading of
  the same file, able to disagree with the first.
- **A stray `#` after a line's fields is refused as L9**, not as whatever rule
  the line's shape happens to break, so the code points at the actual mistake.
- **A refusal points at the offending line**, not the block's head: an unknown
  holder is reported on its `held-by` line.
- **Lines are kept with their text and number**, blank and comment lines
  included, because the proposal tool (104) edits the text and has to put
  every line back where it was.
- **`parse_body` is shared**, so a proposal's `+`/`-` lines are checked by the
  same code that reads a map.
- **Both LuaJIT and Lua 5.4.** `./run-tests` runs every test under each, since
  the point is that two readers agree.
