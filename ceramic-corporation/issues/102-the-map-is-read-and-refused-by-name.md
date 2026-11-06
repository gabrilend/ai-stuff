# 102 — The map is read, and refused by name

| | |
| --- | --- |
| Phase | 1 — The model, and the tools that read it |
| Blocked by | 101 |
| Blocks | 103, 104, 105, 106 |
| Reads | [the org map](../docs/002-the-org-map.md) |

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
